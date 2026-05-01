<?php

namespace App\Observers;

use App\Models\Alert;
use App\Models\Tip;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Support\Facades\Log;
use Throwable;

class TipObserver
{
    public function __construct(protected FcmService $fcm) {}

    /**
     * Broadcast a brand-new active tip to every active user.
     */
    public function created(Tip $tip): void
    {
        if (! $tip->is_active) {
            return;
        }

        $this->broadcast($tip);
    }

    /**
     * Broadcast when an inactive tip becomes active (avoids spam on every edit).
     */
    public function updated(Tip $tip): void
    {
        if ($tip->wasChanged('is_active') && $tip->is_active) {
            $this->broadcast($tip);
        }
    }

    protected function broadcast(Tip $tip): void
    {
        try {
            $users = User::query()
                ->where('is_active', true)
                ->where('is_admin', false)
                ->get(['id', 'language']);

            if ($users->isEmpty()) {
                return;
            }

            // Persist one alert per user through model events so AlertObserver
            // can push FCM with the exact notification_id.
            foreach ($users as $user) {
                Alert::create([
                    'user_id' => $user->id,
                    'budget_category_id' => null,
                    'saving_goal_id' => null,
                    'type' => 'tip',
                    'severity' => 'info',
                    'title_ar' => '💡 '.$tip->title_ar,
                    'title_en' => '💡 '.$tip->title_en,
                    'message_ar' => $tip->content_ar,
                    'message_en' => $tip->content_en,
                    'icon' => $tip->icon ?: 'heroicon-o-light-bulb',
                    'deeplink' => '/tips/'.$tip->id,
                    'payload' => [
                        'tip_id' => $tip->id,
                        'category_id' => $tip->category_id,
                        'icon' => $tip->icon,
                    ],
                    'is_read' => false,
                    'read_at' => null,
                ]);
            }

            // Guest devices don't have user records/alerts, so push directly.
            $guestPayload = [
                'title_ar' => '💡 '.$tip->title_ar,
                'title_en' => '💡 '.$tip->title_en,
                'body_ar' => $tip->content_ar,
                'body_en' => $tip->content_en,
                'data' => [
                    'type' => 'tip',
                    'tip_id' => (string) $tip->id,
                    'category_id' => (string) ($tip->category_id ?? ''),
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                ],
                'severity' => 'info',
            ];

            $stats = $this->fcm->sendToGuestDevices($guestPayload);

            Log::info('Tip broadcast dispatched.', [
                'tip_id' => $tip->id,
                'recipients' => $users->count(),
                'alerts_created' => $users->count(),
                'pushed' => $stats,
            ]);
        } catch (Throwable $e) {
            Log::warning('TipObserver broadcast failed.', [
                'tip_id' => $tip->id,
                'error' => $e->getMessage(),
            ]);
        }
    }
}
