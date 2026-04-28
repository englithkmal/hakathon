<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\TracksNotificationSetting;
use App\Models\Alert;
use App\Models\Tip;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

class SendDailyTip extends Command
{
    use TracksNotificationSetting;

    protected $signature = 'waffer:daily-tip 
                            {--dry-run : Print recipients without sending} 
                            {--force : Run even when disabled in settings}';

    protected $description = 'Send a random active financial tip to every active user.';

    protected string $settingKey = 'daily_tip';

    public function __construct(protected FcmService $fcm)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        if (! $this->ensureEnabled()) {
            return self::SUCCESS;
        }

        $tip = Tip::query()
            ->where('is_active', true)
            ->inRandomOrder()
            ->first();

        if (! $tip) {
            $this->warn('No active tips found. Skipping.');
            $this->recordRun('skipped', ['reason' => 'no_active_tips']);

            return self::SUCCESS;
        }

        $users = User::query()
            ->where('is_active', true)
            ->where('is_admin', false)
            ->get(['id', 'language']);

        if ($users->isEmpty()) {
            $this->warn('No active users to notify.');
            $this->recordRun('skipped', ['reason' => 'no_users']);

            return self::SUCCESS;
        }

        $this->info("Tip selected: #{$tip->id} — \"{$tip->title_ar}\"");
        $this->info("Recipients: {$users->count()} active users.");

        if ($this->option('dry-run')) {
            $this->comment('Dry-run mode — nothing was sent.');

            return self::SUCCESS;
        }

        try {
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
                    'source' => 'daily_scheduled',
                ], JSON_UNESCAPED_UNICODE),
                'is_read' => false,
                'read_at' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ])->all();

            foreach (array_chunk($rows, 500) as $chunk) {
                Alert::insert($chunk);
            }

            $pushPayload = [
                'title_ar' => '💡 نصيحة اليوم',
                'title_en' => '💡 Tip of the day',
                'body_ar' => $tip->title_ar,
                'body_en' => $tip->title_en,
                'data' => [
                    'type' => 'daily_tip',
                    'tip_id' => (string) $tip->id,
                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                ],
                'severity' => 'info',
            ];

            $stats = $this->fcm->sendToUsers($users, $pushPayload);
            $stats = $this->fcm->mergeGuestPushStats($stats, $pushPayload);

            $this->info("✓ Pushed: {$stats['sent']} succeeded, {$stats['failed']} failed.");

            Log::info('Daily tip dispatched.', [
                'tip_id' => $tip->id,
                'recipients' => $users->count(),
                'pushed' => $stats,
            ]);

            $this->recordRun('success', [
                'tip_id' => $tip->id,
                'tip_title' => $tip->title_ar,
                'recipients' => $users->count(),
                'sent' => $stats['sent'],
                'failed' => $stats['failed'],
            ]);
        } catch (Throwable $e) {
            $this->error('Failed: '.$e->getMessage());
            Log::error('Daily tip failed.', ['error' => $e->getMessage()]);
            $this->recordRun('failed', ['error' => $e->getMessage()]);

            return self::FAILURE;
        }

        return self::SUCCESS;
    }
}
