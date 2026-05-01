<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\TracksNotificationSetting;
use App\Models\Alert;
use App\Models\SavingGoal;
use App\Services\FcmService;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Walks every active saving goal and emits a `goal_off_track` alert if the
 * pace classification (computed from start_date/deadline vs current_amount)
 * resolves to off_track. Throttled to one alert per goal per calendar month
 * so users don't get spammed every cron tick.
 *
 * Recommended schedule: monthly on day 1 at 10:00 (notification_settings:
 * key=goal_pace_check). Can also be triggered manually with --force.
 */
class GoalPaceCheck extends Command
{
    use TracksNotificationSetting;

    protected $signature = 'waffer:goal-pace-check
                            {--user= : Limit to a single user_id}
                            {--goal= : Limit to a single goal id}
                            {--dry-run : Print what would alert, send nothing}
                            {--force : Run even when disabled in notification_settings}';

    protected $description = 'Detect saving goals that are behind plan and emit goal_off_track alerts (deduped per month).';

    protected string $settingKey = 'goal_pace_check';

    public function __construct(protected FcmService $fcm)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        if (! $this->ensureEnabled()) {
            return self::SUCCESS;
        }

        $now = Carbon::now(config('app.timezone'));
        $monthBucket = $now->format('Y-m');

        $goals = SavingGoal::query()
            ->with('user:id,name,language,currency')
            ->where('status', 'active')
            ->whereNotNull('start_date')
            ->whereNotNull('deadline')
            ->when($this->option('user'), fn ($q, $id) => $q->where('user_id', (int) $id))
            ->when($this->option('goal'), fn ($q, $id) => $q->whereKey((int) $id))
            ->get();

        $checked = 0;
        $offTrack = 0;
        $alerted = 0;
        $skippedDuplicate = 0;
        $dryRun = (bool) $this->option('dry-run');

        foreach ($goals as $goal) {
            $checked++;

            if ($goal->pace_status !== 'off_track') {
                continue;
            }

            $offTrack++;

            // Dedupe: at most one off_track alert per goal per calendar month.
            $alreadyAlerted = Alert::query()
                ->where('user_id', $goal->user_id)
                ->where('saving_goal_id', $goal->id)
                ->where('type', 'goal_off_track')
                ->where('created_at', '>=', $now->copy()->startOfMonth())
                ->exists();

            if ($alreadyAlerted) {
                $skippedDuplicate++;
                continue;
            }

            if ($dryRun) {
                $this->line(sprintf(
                    '  • would alert goal#%d "%s" — current=%.2f expected=%.2f delta=%.2f',
                    $goal->id,
                    $goal->title,
                    (float) $goal->current_amount,
                    (float) ($goal->expected_at_today ?? 0),
                    (float) ($goal->pace_delta ?? 0),
                ));
                continue;
            }

            try {
                $this->dispatchOffTrackAlert($goal, $monthBucket);
                $alerted++;
            } catch (Throwable $e) {
                Log::warning('goal_off_track dispatch failed.', [
                    'goal_id' => $goal->id,
                    'user_id' => $goal->user_id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        $this->table(
            ['Goals checked', 'Off-track', 'Alerted', 'Skipped (already alerted)'],
            [[$checked, $offTrack, $alerted, $skippedDuplicate]]
        );

        $this->recordRun('success', [
            'month' => $monthBucket,
            'checked' => $checked,
            'off_track' => $offTrack,
            'alerted' => $alerted,
            'skipped_duplicate' => $skippedDuplicate,
        ]);

        return self::SUCCESS;
    }

    protected function dispatchOffTrackAlert(SavingGoal $goal, string $monthBucket): void
    {
        $user = $goal->user;
        if (! $user) {
            return;
        }

        $currency = $goal->currency ?? $user->currency ?? 'SAR';
        $delta = abs((float) ($goal->pace_delta ?? 0));
        $pct = (float) $goal->progress_percentage;

        $titleAr = "⚠️ هدف متأخر: {$goal->title}";
        $titleEn = "⚠️ Goal off track: {$goal->title}";
        $messageAr = sprintf(
            'أنت متأخر بـ %s %s عن الخطة. تقدّمك %s%% من المستهدف.',
            number_format($delta, 2),
            $currency,
            number_format($pct, 1)
        );
        $messageEn = sprintf(
            "You're behind by %s %s. Progress %s%% of target.",
            number_format($delta, 2),
            $currency,
            number_format($pct, 1)
        );

        $alert = Alert::create([
            'user_id' => $user->id,
            'saving_goal_id' => $goal->id,
            'type' => 'goal_off_track',
            'severity' => 'warning',
            'title_ar' => $titleAr,
            'title_en' => $titleEn,
            'message_ar' => $messageAr,
            'message_en' => $messageEn,
            'icon' => 'heroicon-o-arrow-trending-down',
            'deeplink' => '/goals/'.$goal->id,
            'payload' => [
                'kind' => 'goal_off_track',
                'goal_id' => $goal->id,
                'goal_title' => $goal->title,
                'current_amount' => (float) $goal->current_amount,
                'target_amount' => (float) $goal->target_amount,
                'expected_at_today' => $goal->expected_at_today,
                'pace_delta' => $goal->pace_delta,
                'progress_percentage' => $pct,
                'month' => $monthBucket,
            ],
        ]);

        $this->fcm->sendToUser($user, [
            'title_ar' => $titleAr,
            'title_en' => $titleEn,
            'body_ar' => $messageAr,
            'body_en' => $messageEn,
            'data' => [
                'type' => 'goal_off_track',
                'alert_id' => (string) $alert->id,
                'goal_id' => (string) $goal->id,
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            ],
            'severity' => 'warning',
        ]);
    }
}
