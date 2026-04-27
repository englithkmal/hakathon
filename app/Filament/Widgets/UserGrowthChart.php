<?php

namespace App\Filament\Widgets;

use App\Models\User;
use Filament\Widgets\ChartWidget;

class UserGrowthChart extends ChartWidget
{
    protected static ?int $sort = 4;

    protected int|string|array $columnSpan = 1;

    public function getHeading(): string|\Illuminate\Contracts\Support\Htmlable|null
    {
        return app()->getLocale() === 'ar'
            ? 'نمو المستخدمين (آخر 30 يوم)'
            : 'User Growth (Last 30 Days)';
    }

    protected function getData(): array
    {
        $days = collect();
        $counts = [];

        for ($i = 29; $i >= 0; $i--) {
            $date = now()->subDays($i);
            $days->push($date->format('m-d'));

            $count = User::where('is_admin', false)
                ->whereDate('created_at', '<=', $date->endOfDay())
                ->count();

            $counts[] = $count;
        }

        $label = app()->getLocale() === 'ar'
            ? 'إجمالي المستخدمين'
            : 'Total Users';

        return [
            'datasets' => [[
                'label' => $label,
                'data' => $counts,
                'backgroundColor' => 'rgba(245, 158, 11, 0.2)',
                'borderColor' => 'rgb(245, 158, 11)',
                'borderWidth' => 2,
                'fill' => true,
                'tension' => 0.4,
            ]],
            'labels' => $days->all(),
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }

    protected function getOptions(): array
    {
        return [
            'plugins' => [
                'legend' => ['display' => false],
            ],
            'scales' => [
                'y' => ['beginAtZero' => true],
            ],
        ];
    }
}
