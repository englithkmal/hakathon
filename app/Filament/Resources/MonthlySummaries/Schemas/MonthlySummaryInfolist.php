<?php

namespace App\Filament\Resources\MonthlySummaries\Schemas;

use App\Models\MonthlySummary;
use Filament\Infolists\Components\RepeatableEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Grid;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class MonthlySummaryInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('الفترة والمستخدم')
                ->columns(3)
                ->schema([
                    TextEntry::make('user.name')->label('المستخدم'),
                    TextEntry::make('period_label')
                        ->label('الفترة')
                        ->state(fn (MonthlySummary $r) => sprintf('%02d/%d', $r->month, $r->year)),
                    TextEntry::make('period_range')
                        ->label('من / إلى')
                        ->state(fn (MonthlySummary $r) => $r->period_start?->toDateString().' → '.$r->period_end?->toDateString()),
                    TextEntry::make('closed_at')->label('وقت الإغلاق')->dateTime('Y-m-d H:i'),
                    TextEntry::make('closed_by')
                        ->label('طريقة الإغلاق')
                        ->badge()
                        ->formatStateUsing(fn (string $state) => $state === MonthlySummary::CLOSED_BY_MANUAL ? 'يدوي' : 'تلقائي')
                        ->color(fn (string $state) => $state === MonthlySummary::CLOSED_BY_MANUAL ? 'warning' : 'info'),
                    TextEntry::make('transaction_count')->label('عدد المعاملات')->numeric(),
                ]),

            Section::make('التدفق المالي')
                ->columns(4)
                ->schema([
                    TextEntry::make('total_income')
                        ->label('الدخل')
                        ->numeric(2)
                        ->color('success'),
                    TextEntry::make('total_expenses')
                        ->label('المصروف')
                        ->numeric(2)
                        ->color('danger'),
                    TextEntry::make('total_goal_deposits')
                        ->label('إيداعات الأهداف')
                        ->numeric(2)
                        ->color('info'),
                    TextEntry::make('unallocated_savings')
                        ->label('وفر الشهر (غير مخصّص)')
                        ->numeric(2)
                        ->color(fn ($state) => (float) $state > 0 ? 'success' : 'gray'),
                ]),

            Section::make('الميزانية')
                ->columns(4)
                ->visible(fn (MonthlySummary $r) => $r->budget_id !== null)
                ->schema([
                    TextEntry::make('budget_total_amount')
                        ->label('سقف الميزانية')
                        ->numeric(2),
                    TextEntry::make('budget_total_spent')
                        ->label('المصروف منها')
                        ->numeric(2),
                    TextEntry::make('budget_adherence_pct')
                        ->label('% الالتزام')
                        ->state(fn (MonthlySummary $r) => $r->budget_adherence_pct === null ? '—' : $r->budget_adherence_pct.'%')
                        ->color(fn (MonthlySummary $r) => match (true) {
                            $r->budget_adherence_pct === null => 'gray',
                            $r->budget_adherence_pct > 100 => 'danger',
                            $r->budget_adherence_pct >= 80 => 'warning',
                            default => 'success',
                        }),
                    TextEntry::make('budget_id')
                        ->label('رقم الميزانية')
                        ->prefix('#'),
                ]),

            Section::make('التخصيص (الوفر إلى أهداف)')
                ->columns(3)
                ->schema([
                    TextEntry::make('allocation_status')
                        ->label('الحالة')
                        ->badge()
                        ->formatStateUsing(fn (string $state): string => match ($state) {
                            MonthlySummary::ALLOCATION_UNALLOCATED => 'غير مخصّص',
                            MonthlySummary::ALLOCATION_PARTIAL => 'مخصّص جزئياً',
                            MonthlySummary::ALLOCATION_FULL => 'مخصّص بالكامل',
                            default => $state,
                        })
                        ->color(fn (string $state): string => match ($state) {
                            MonthlySummary::ALLOCATION_FULL => 'success',
                            MonthlySummary::ALLOCATION_PARTIAL => 'warning',
                            default => 'gray',
                        }),
                    TextEntry::make('allocated_amount')
                        ->label('المبلغ المخصّص')
                        ->numeric(2),
                    TextEntry::make('unallocated_remaining')
                        ->label('المتبقي بدون تخصيص')
                        ->state(fn (MonthlySummary $r) => $r->unallocated_remaining)
                        ->numeric(2)
                        ->color(fn ($state) => (float) $state > 0 ? 'warning' : 'success'),
                ]),

            Section::make('أعلى الفئات صرفاً')
                ->visible(fn (MonthlySummary $r) => is_array($r->top_categories) && count($r->top_categories) > 0)
                ->schema([
                    RepeatableEntry::make('top_categories')
                        ->label('')
                        ->columns(4)
                        ->schema([
                            TextEntry::make('name_ar')->label('الفئة')->weight('bold'),
                            TextEntry::make('total')->label('المجموع')->numeric(2),
                            TextEntry::make('count')->label('عدد المعاملات')->numeric(),
                            TextEntry::make('percentage')
                                ->label('% من المصروف')
                                ->state(fn ($state) => $state.'%')
                                ->color(fn ($state) => (float) $state >= 50 ? 'danger' : ((float) $state >= 25 ? 'warning' : 'gray')),
                        ]),
                ]),

            Section::make('ملاحظات')
                ->visible(fn (MonthlySummary $r) => filled($r->notes))
                ->schema([
                    TextEntry::make('notes')->label('')->columnSpanFull(),
                ]),
        ]);
    }
}
