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

            // 1) Persist Alert rows (so they show up in the in-app notifications list).
            $rows = $users->map(fn (User $user) => [
                'user_id' => $user->id,
                'budget_category_id' => null,
                'saving_goal_id' => null,
                'type' => 'tip',
                'severity' => 'info',
                'title_ar' => '💡 '.$tip->title_ar,
                'title_en' => '💡 '.$tip->title_en,
                'message_ar' => $tip->content_ar,
                'message_en' => $tip->content_en,
                'payload' => json_encode([
                    'tip_id' => $tip->id,
                    'category_id' => $tip->category_id,
                    'icon' => $tip->icon,
                ], JSON_UNESCAPED_UNICODE),
                'is_read' => false,
                'read_at' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ])->all();

            foreach (array_chunk($rows, 500) as $chunk) {
                Alert::insert($chunk);
            }

            // 2) Push via FCM directly (insert() bypasses model events on purpose
            //    so we don't fire AlertObserver thousands of times in a loop).
            $payload = [
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

            $stats = $this->fcm->sendToUsers($users, $payload);
            $stats = $this->fcm->mergeGuestPushStats($stats, $payload);

            Log::info('Tip broadcast dispatched.', [
                'tip_id' => $tip->id,
                'recipients' => $users->count(),
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
