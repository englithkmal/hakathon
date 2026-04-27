<?php

namespace App\Filament\Widgets;

use App\Models\Budget;
use App\Models\SavingGoal;
use App\Models\Transaction;
use App\Models\User;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class WafferStatsOverview extends StatsOverviewWidget
{
    public function getHeading(): ?string
    {
        return __('waffer.widgets.overview');
    }

    protected function getStats(): array
    {
        $totalUsers = User::where('is_admin', false)->count();
        $activeUsers = User::where('is_admin', false)->where('is_active', true)->count();

        $totalBudgets = Budget::count();
        $activeBudgets = Budget::where('status', 'active')->count();

        $totalTransactions = Transaction::count();
        $thisMonthSpent = Transaction::where('type', 'expense')
            ->whereMonth('transaction_date', now()->month)
            ->whereYear('transaction_date', now()->year)
            ->sum('amount');

        $totalSavingGoals = SavingGoal::count();
        $achievedGoals = SavingGoal::where('status', 'achieved')->count();

        $of = app()->getLocale() === 'ar' ? 'من أصل' : 'of';
        $transactionsLabel = app()->getLocale() === 'ar' ? 'معاملة إجمالية' : 'total transactions';
        $goalLabel = app()->getLocale() === 'ar' ? 'هدف' : 'goals';

        return [
            Stat::make(__('waffer.widgets.total_users'), number_format($totalUsers))
                ->description($activeUsers.' '.__('waffer.widgets.active_users'))
                ->descriptionIcon('heroicon-m-user-group')
                ->color('success'),

            Stat::make(__('waffer.widgets.active_budgets'), number_format($activeBudgets))
                ->description($of.' '.number_format($totalBudgets))
                ->descriptionIcon('heroicon-m-chart-pie')
                ->color('info'),

            Stat::make(__('waffer.widgets.monthly_expenses'), number_format($thisMonthSpent, 2))
                ->description(number_format($totalTransactions).' '.$transactionsLabel)
                ->descriptionIcon('heroicon-m-banknotes')
                ->color('warning'),

            Stat::make(__('waffer.widgets.achieved_goals'), number_format($achievedGoals))
                ->description($of.' '.number_format($totalSavingGoals).' '.$goalLabel)
                ->descriptionIcon('heroicon-m-flag')
                ->color('success'),
        ];
    }
}
