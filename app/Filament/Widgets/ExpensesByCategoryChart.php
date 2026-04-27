<?php

namespace App\Filament\Widgets;

use App\Models\Transaction;
use Filament\Widgets\ChartWidget;

class ExpensesByCategoryChart extends ChartWidget
{
    protected static ?int $sort = 3;

    protected int|string|array $columnSpan = 1;

    public function getHeading(): string|\Illuminate\Contracts\Support\Htmlable|null
    {
        return app()->getLocale() === 'ar'
            ? 'توزيع مصروفات الشهر الحالي'
            : 'Current Month Expenses by Category';
    }

    protected function getData(): array
    {
        $isArabic = app()->getLocale() === 'ar';
        $nameField = $isArabic ? 'name_ar' : 'name_en';

        $rows = Transaction::query()
            ->where('transactions.type', 'expense')
            ->whereMonth('transaction_date', now()->month)
            ->whereYear('transaction_date', now()->year)
            ->whereNotNull('category_id')
            ->join('categories', 'transactions.category_id', '=', 'categories.id')
            ->selectRaw("categories.{$nameField} as label, categories.color as color, SUM(transactions.amount) as total")
            ->groupBy('categories.id', 'label', 'color')
            ->orderByDesc('total')
            ->get();

        $emptyLabel = $isArabic ? 'لا توجد بيانات' : 'No data';

        if ($rows->isEmpty()) {
            return [
                'datasets' => [['data' => [1], 'backgroundColor' => ['#E5E7EB']]],
                'labels' => [$emptyLabel],
            ];
        }

        return [
            'datasets' => [[
                'data' => $rows->pluck('total')->all(),
                'backgroundColor' => $rows->pluck('color')->map(fn ($c) => $c ?: '#9CA3AF')->all(),
                'borderWidth' => 2,
                'borderColor' => '#fff',
            ]],
            'labels' => $rows->pluck('label')->all(),
        ];
    }

    protected function getType(): string
    {
        return 'doughnut';
    }

    protected function getOptions(): array
    {
        return [
            'plugins' => [
                'legend' => [
                    'display' => true,
                    'position' => 'right',
                ],
            ],
        ];
    }
}
