<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\TracksNotificationSetting;
use App\Models\MonthlySummary;
use App\Models\User;
use App\Services\MonthlyCloser;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Closes a calendar month for one or all users:
 *  - creates an immutable monthly_summaries row,
 *  - flips the matching active budget to status=closed,
 *  - dispatches a `monthly_summary_ready` alert + FCM push.
 *
 * Default schedule: day 1 of every month at 02:00 Riyadh (precedes
 * waffer:monthly-report at 09:00 — the report reads from the snapshot).
 */
class CloseMonth extends Command
{
    use TracksNotificationSetting;

    protected $signature = 'waffer:close-month
                            {--month= : Override target month (YYYY-MM). Defaults to the previous calendar month.}
                            {--user= : Limit to a single user_id}
                            {--force : Recompute even if a summary already exists for this month}
                            {--dry-run : Print actions without writing}';

    protected $description = 'Build the immutable monthly snapshot for the previous month, lock the budget, and notify users.';

    protected string $settingKey = 'monthly_close';

    public function __construct(protected MonthlyCloser $closer)
    {
        parent::__construct();
    }

    public function handle(): int
    {
        // We only honor the enabled flag when the setting actually exists. This
        // command is core (BR-06): the report depends on it. Setting can disable
        // the *push* notification, but the snapshot itself must always be built.
        $setting = $this->setting();
        if ($setting && ! $this->shouldRespectEnabledFlag()) {
            // explicit --force overrides
        }

        $target = $this->option('month')
            ? Carbon::createFromFormat('Y-m', $this->option('month'))->startOfMonth()
            : now()->subMonthNoOverflow()->startOfMonth();

        $year = (int) $target->year;
        $month = (int) $target->month;
        $force = (bool) $this->option('force');
        $dryRun = (bool) $this->option('dry-run');

        $this->info("Closing {$year}-".str_pad((string) $month, 2, '0', STR_PAD_LEFT).($force ? ' (force)' : '').($dryRun ? ' [dry-run]' : ''));

        $users = User::query()
            ->where('is_active', true)
            ->where('is_admin', false)
            ->when($this->option('user'), fn ($q, $id) => $q->whereKey((int) $id))
            ->get(['id', 'name', 'currency']);

        if ($users->isEmpty()) {
            $this->warn('No matching users.');

            return self::SUCCESS;
        }

        $created = 0;
        $updated = 0;
        $skipped = 0;
        $failed = 0;

        foreach ($users as $user) {
            try {
                if ($dryRun) {
                    $this->line("  • would close {$user->name} (#{$user->id}) {$year}-{$month}");
                    continue;
                }

                $existedBefore = MonthlySummary::query()
                    ->where('user_id', $user->id)
                    ->where('year', $year)
                    ->where('month', $month)
                    ->exists();

                $summary = $this->closer->closeUserMonth(
                    $user,
                    $year,
                    $month,
                    closedBy: MonthlySummary::CLOSED_BY_CRON,
                    force: $force,
                );

                if ($summary === null) {
                    $skipped++;
                    continue;
                }

                $existedBefore ? $updated++ : $created++;
            } catch (Throwable $e) {
                $failed++;
                Log::error('CloseMonth failed for user.', [
                    'user_id' => $user->id,
                    'year' => $year,
                    'month' => $month,
                    'error' => $e->getMessage(),
                ]);
                $this->error("  ✗ user#{$user->id}: {$e->getMessage()}");
            }
        }

        $this->table(
            ['Created', 'Updated (force)', 'Skipped (empty)', 'Failed'],
            [[$created, $updated, $skipped, $failed]]
        );

        $this->recordRun($failed > 0 ? 'partial' : 'success', [
            'year' => $year,
            'month' => $month,
            'created' => $created,
            'updated' => $updated,
            'skipped' => $skipped,
            'failed' => $failed,
        ]);

        return $failed > 0 ? self::FAILURE : self::SUCCESS;
    }
}
