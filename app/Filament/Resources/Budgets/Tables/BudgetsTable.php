<?php

namespace App\Filament\Resources\Budgets\Tables;

use App\Filament\Exports\BudgetExporter;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\ExportAction;
use Filament\Actions\ExportBulkAction;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class BudgetsTable
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

                TextColumn::make('month')
                    ->label('الشهر')
                    ->formatStateUsing(fn ($state, $record) => $record->month.'/'.$record->year)
                    ->sortable(),

                TextColumn::make('total_income')
                    ->label('الدخل')
                    ->numeric(2)
                    ->sortable(),

                TextColumn::make('total_amount')
                    ->label('الميزانية')
                    ->numeric(2)
                    ->sortable(),

                TextColumn::make('total_spent')
                    ->label('المصروف')
                    ->numeric(2)
                    ->color('danger')
                    ->sortable(),

                TextColumn::make('remaining')
                    ->label('المتبقي')
                    ->state(fn ($record) => number_format($record->remaining, 2))
                    ->color('success'),

                TextColumn::make('progress_percentage')
                    ->label('% الاستهلاك')
                    ->state(fn ($record) => $record->progress_percentage.'%')
                    ->color(fn ($record) => $record->progress_percentage >= 100 ? 'danger' : ($record->progress_percentage >= 80 ? 'warning' : 'success')),

                TextColumn::make('currency')
                    ->label('العملة')
                    ->badge(),

                TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'active' => 'نشطة',
                        'closed' => 'مغلقة',
                        'draft' => 'مسودة',
                        default => $state,
                    })
                    ->color(fn (string $state): string => match ($state) {
                        'active' => 'success',
                        'closed' => 'gray',
                        'draft' => 'warning',
                        default => 'gray',
                    }),

                TextColumn::make('created_at')
                    ->label('تاريخ الإنشاء')
                    ->dateTime('Y-m-d')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->label('الحالة')
                    ->options([
                        'active' => 'نشطة',
                        'closed' => 'مغلقة',
                        'draft' => 'مسودة',
                    ]),

                SelectFilter::make('year')
                    ->label('السنة')
                    ->options(function () {
                        $years = \App\Models\Budget::query()->distinct()->pluck('year')->toArray();

                        return array_combine($years, $years);
                    }),
            ])
            ->recordActions([
                ViewAction::make()->label('عرض'),
            ])
            ->headerActions([
                ExportAction::make()
                    ->label(__('waffer.actions.export'))
                    ->exporter(BudgetExporter::class),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    ExportBulkAction::make()
                        ->label(__('waffer.actions.export'))
                        ->exporter(BudgetExporter::class),
                ]),
            ]);
    }
}
