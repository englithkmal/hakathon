<?php

namespace App\Filament\Widgets;

use App\Models\Transaction;
use Filament\Widgets\ChartWidget;
use Illuminate\Support\Carbon;

class IncomeVsExpensesChart extends ChartWidget
{
    protected ?string $heading = null;

    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    public function getHeading(): string|\Illuminate\Contracts\Support\Htmlable|null
    {
        return app()->getLocale() === 'ar'
            ? 'الدخل مقابل المصروفات (آخر 6 أشهر)'
            : 'Income vs Expenses (Last 6 Months)';
    }

    protected function getData(): array
    {
        $months = collect();
        $incomeData = [];
        $expenseData = [];
        $savingData = [];

        for ($i = 5; $i >= 0; $i--) {
            $date = now()->subMonths($i);
            $monthLabel = app()->getLocale() === 'ar'
                ? $date->translatedFormat('M Y')
                : $date->format('M Y');

            $months->push($monthLabel);

            $base = Transaction::whereMonth('transaction_date', $date->month)
                ->whereYear('transaction_date', $date->year);

            $incomeData[] = (float) (clone $base)->where('type', 'income')->sum('amount');
            $expenseData[] = (float) (clone $base)->where('type', 'expense')->sum('amount');
            $savingData[] = (float) (clone $base)->where('type', 'saving')->sum('amount');
        }

        $labels = app()->getLocale() === 'ar'
            ? ['الدخل', 'المصروفات', 'الادخار']
            : ['Income', 'Expenses', 'Savings'];

        return [
            'datasets' => [
                [
                    'label' => $labels[0],
                    'data' => $incomeData,
                    'backgroundColor' => 'rgba(34, 197, 94, 0.6)',
                    'borderColor' => 'rgb(34, 197, 94)',
                    'borderWidth' => 2,
                ],
                [
                    'label' => $labels[1],
                    'data' => $expenseData,
                    'backgroundColor' => 'rgba(239, 68, 68, 0.6)',
                    'borderColor' => 'rgb(239, 68, 68)',
                    'borderWidth' => 2,
                ],
                [
                    'label' => $labels[2],
                    'data' => $savingData,
                    'backgroundColor' => 'rgba(59, 130, 246, 0.6)',
                    'borderColor' => 'rgb(59, 130, 246)',
                    'borderWidth' => 2,
                ],
            ],
            'labels' => $months->all(),
        ];
    }

    protected function getType(): string
    {
        return 'bar';
    }

    protected function getOptions(): array
    {
        return [
            'plugins' => [
                'legend' => [
                    'display' => true,
                    'position' => 'top',
                ],
            ],
            'scales' => [
                'y' => [
                    'beginAtZero' => true,
                ],
            ],
        ];
    }
}
