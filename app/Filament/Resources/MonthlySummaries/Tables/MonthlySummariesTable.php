<?php

namespace App\Filament\Resources\MonthlySummaries\Tables;

use App\Models\MonthlySummary;
use App\Services\MonthlyCloser;
use Filament\Actions\Action;
use Filament\Actions\ActionGroup;
use Filament\Actions\ViewAction;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class MonthlySummariesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('user.name')
                    ->label('المستخدم')
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),

                TextColumn::make('period')
                    ->label('الفترة')
                    ->state(fn (MonthlySummary $r) => sprintf('%02d/%d', $r->month, $r->year))
                    ->sortable(query: fn ($query, string $direction) => $query
                        ->orderBy('year', $direction)
                        ->orderBy('month', $direction)),

                TextColumn::make('total_income')
                    ->label('الدخل')
                    ->numeric(2)
                    ->color('success')
                    ->sortable(),

                TextColumn::make('total_expenses')
                    ->label('المصروف')
                    ->numeric(2)
                    ->color('danger')
                    ->sortable(),

                TextColumn::make('total_goal_deposits')
                    ->label('إيداعات الأهداف')
                    ->numeric(2)
                    ->color('info')
                    ->toggleable(),

                TextColumn::make('unallocated_savings')
                    ->label('وفر الشهر')
                    ->numeric(2)
                    ->color(fn ($state) => (float) $state > 0 ? 'success' : 'gray')
                    ->sortable(),

                TextColumn::make('budget_adherence_pct')
                    ->label('الالتزام بالميزانية')
                    ->state(fn (MonthlySummary $r) => $r->budget_adherence_pct === null ? '—' : $r->budget_adherence_pct.'%')
                    ->color(fn (MonthlySummary $r) => match (true) {
                        $r->budget_adherence_pct === null => 'gray',
                        $r->budget_adherence_pct > 100 => 'danger',
                        $r->budget_adherence_pct >= 80 => 'warning',
                        default => 'success',
                    })
                    ->toggleable(),

                TextColumn::make('allocation_status')
                    ->label('حالة التخصيص')
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
                        MonthlySummary::ALLOCATION_UNALLOCATED => 'gray',
                        default => 'gray',
                    }),

                TextColumn::make('transaction_count')
                    ->label('عدد المعاملات')
                    ->numeric()
                    ->toggleable(isToggledHiddenByDefault: true),

                TextColumn::make('closed_by')
                    ->label('طريقة الإغلاق')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        MonthlySummary::CLOSED_BY_CRON => 'تلقائي',
                        MonthlySummary::CLOSED_BY_MANUAL => 'يدوي',
                        default => $state,
                    })
                    ->color(fn (string $state): string => $state === MonthlySummary::CLOSED_BY_MANUAL ? 'warning' : 'info'),

                TextColumn::make('closed_at')
                    ->label('تاريخ الإغلاق')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->defaultSort('closed_at', 'desc')
            ->filters([
                SelectFilter::make('year')
                    ->label('السنة')
                    ->options(function () {
                        $years = MonthlySummary::query()->distinct()->pluck('year')->sortDesc()->toArray();

                        return array_combine($years, $years);
                    }),

                SelectFilter::make('month')
                    ->label('الشهر')
                    ->options([
                        1 => 'يناير', 2 => 'فبراير', 3 => 'مارس', 4 => 'أبريل',
                        5 => 'مايو', 6 => 'يونيو', 7 => 'يوليو', 8 => 'أغسطس',
                        9 => 'سبتمبر', 10 => 'أكتوبر', 11 => 'نوفمبر', 12 => 'ديسمبر',
                    ]),

                SelectFilter::make('allocation_status')
                    ->label('حالة التخصيص')
                    ->options([
                        MonthlySummary::ALLOCATION_UNALLOCATED => 'غير مخصّص',
                        MonthlySummary::ALLOCATION_PARTIAL => 'مخصّص جزئياً',
                        MonthlySummary::ALLOCATION_FULL => 'مخصّص بالكامل',
                    ]),

                SelectFilter::make('closed_by')
                    ->label('طريقة الإغلاق')
                    ->options([
                        MonthlySummary::CLOSED_BY_CRON => 'تلقائي',
                        MonthlySummary::CLOSED_BY_MANUAL => 'يدوي',
                    ]),
            ])
            ->recordActions([
                ActionGroup::make([
                    ViewAction::make()->label('عرض'),

                    Action::make('recompute')
                        ->label('إعادة الحساب (Force)')
                        ->icon('heroicon-o-arrow-path')
                        ->color('warning')
                        ->requiresConfirmation()
                        ->modalHeading('إعادة احتساب التقرير الشهري')
                        ->modalDescription('سيتم إعادة قراءة جميع المعاملات لهذا الشهر وتحديث الأرقام. الـ closed_at لن يتغير. تابع؟')
                        ->modalSubmitActionLabel('إعادة الحساب')
                        ->action(function (MonthlySummary $record, MonthlyCloser $closer) {
                            $summary = $closer->closeUserMonth(
                                $record->user,
                                (int) $record->year,
                                (int) $record->month,
                                MonthlySummary::CLOSED_BY_MANUAL,
                                force: true,
                            );

                            Notification::make()
                                ->title('تم إعادة الحساب')
                                ->body($summary
                                    ? "الدخل: {$summary->total_income} | المصروف: {$summary->total_expenses} | الوفر: {$summary->unallocated_savings}"
                                    : 'لم يتم تحديث أي شيء (لا توجد بيانات).')
                                ->success()
                                ->send();
                        }),
                ])->iconButton(),
            ]);
    }
}
