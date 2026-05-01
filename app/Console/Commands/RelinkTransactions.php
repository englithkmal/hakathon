<?php

namespace App\Console\Commands;

use App\Models\Budget;
use App\Models\Transaction;
use App\Services\BudgetLinker;
use Illuminate\Console\Command;

class RelinkTransactions extends Command
{
    protected $signature = 'transactions:relink
                            {--user= : Limit to a single user_id}
                            {--dry-run : Report changes without writing}';

    protected $description = 'Backfill / fix transactions.budget_id based on date+user. Re-syncs all budget aggregates.';

    public function handle(BudgetLinker $linker): int
    {
        $userId = $this->option('user');
        $dryRun = (bool) $this->option('dry-run');

        $base = Transaction::query()->where('type', 'expense');
        if ($userId) {
            $base->where('user_id', (int) $userId);
        }

        $total = (clone $base)->count();
        $this->info("Scanning {$total} expense transaction(s)…");

        $changed = 0;
        $cleared = 0;
        $unchanged = 0;

        $base->orderBy('id')->chunkById(500, function ($chunk) use ($linker, $dryRun, &$changed, &$cleared, &$unchanged) {
            foreach ($chunk as $tx) {
                $current = $tx->budget_id;
                $linker->attachBudgetIdInPlace($tx);
                $next = $tx->budget_id;

                if ($current === $next) {
                    $unchanged++;

                    continue;
                }

                if ($next === null) {
                    $cleared++;
                } else {
                    $changed++;
                }

                if (! $dryRun) {
                    $tx->saveQuietly();
                }
            }
        });

        $this->table(
            ['Re-pointed', 'Cleared (no budget)', 'Unchanged'],
            [[$changed, $cleared, $unchanged]]
        );

        if (! $dryRun) {
            $this->info('Recalculating affected budget aggregates…');

            $budgets = Budget::query();
            if ($userId) {
                $budgets->where('user_id', (int) $userId);
            }

            $budgets->each(function (Budget $budget) use ($linker) {
                $linker->recalculateBudget($budget);
            });
        }

        $this->info($dryRun ? 'Dry run complete. No changes written.' : 'Done.');

        return self::SUCCESS;
    }
}
