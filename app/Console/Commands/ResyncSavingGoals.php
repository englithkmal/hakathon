<?php

namespace App\Console\Commands;

use App\Models\SavingGoal;
use App\Services\SavingGoalLinker;
use Illuminate\Console\Command;

/**
 * One-shot data integrity tool — equivalent of `transactions:relink` for goals.
 * Walks every saving goal and rebuilds `current_amount` from its deposits.
 * Safe to re-run; uses saveQuietly inside the linker so it never fans out
 * into observer chains.
 *
 * Use cases:
 *   - After importing legacy data
 *   - After a manual SQL fix to transactions
 *   - After changing the definition of "what counts as a deposit"
 */
class ResyncSavingGoals extends Command
{
    protected $signature = 'saving-goals:resync
                            {--user= : Limit to a single user_id}
                            {--goal= : Limit to a single goal id}
                            {--dry-run : Report drift without writing}';

    protected $description = 'Recompute saving_goals.current_amount from transactions for every (or one) goal.';

    public function handle(SavingGoalLinker $linker): int
    {
        $dryRun = (bool) $this->option('dry-run');

        $query = SavingGoal::query()
            ->when($this->option('user'), fn ($q, $id) => $q->where('user_id', (int) $id))
            ->when($this->option('goal'), fn ($q, $id) => $q->whereKey((int) $id));

        $total = (clone $query)->count();
        $this->info("Scanning {$total} saving goal(s)…");

        $changed = 0;
        $unchanged = 0;
        $achievedFlipped = 0;

        $query->orderBy('id')->chunkById(200, function ($chunk) use ($linker, $dryRun, &$changed, &$unchanged, &$achievedFlipped) {
            foreach ($chunk as $goal) {
                $previousAmount = (float) $goal->current_amount;
                $previousStatus = (string) $goal->status;

                if ($dryRun) {
                    $expected = (float) \App\Models\Transaction::query()
                        ->where('saving_goal_id', $goal->id)
                        ->where('type', 'saving')
                        ->sum('amount');

                    if (abs($expected - $previousAmount) > 0.001) {
                        $this->line(sprintf(
                            '  • goal#%d "%s": %.2f → %.2f (drift %+.2f)',
                            $goal->id,
                            $goal->title,
                            $previousAmount,
                            $expected,
                            $expected - $previousAmount,
                        ));
                        $changed++;
                    } else {
                        $unchanged++;
                    }

                    continue;
                }

                $linker->recompute($goal);
                $goal->refresh();

                $newAmount = (float) $goal->current_amount;
                $newStatus = (string) $goal->status;

                if (abs($newAmount - $previousAmount) > 0.001) {
                    $changed++;
                } else {
                    $unchanged++;
                }

                if ($previousStatus === 'active' && $newStatus === 'achieved') {
                    $achievedFlipped++;
                }
            }
        });

        $this->table(
            ['Re-synced', 'Unchanged', 'Auto-marked achieved'],
            [[$changed, $unchanged, $achievedFlipped]]
        );

        $this->info($dryRun ? 'Dry run complete. No changes written.' : 'Done.');

        return self::SUCCESS;
    }
}
