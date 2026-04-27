<?php

namespace App\Filament\Resources\Transactions\Tables;

use App\Filament\Exports\TransactionExporter;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\ExportAction;
use Filament\Actions\ExportBulkAction;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class TransactionsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('user.name')
                    ->label('المستخدم')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('description')
                    ->label('الوصف')
                    ->searchable()
                    ->wrap()
                    ->placeholder('—'),

                TextColumn::make('merchant')
                    ->label('الجهة')
                    ->searchable()
                    ->placeholder('—')
                    ->toggleable(),

                TextColumn::make('amount')
                    ->label('المبلغ')
                    ->numeric(2)
                    ->sortable()
                    ->color(fn ($record) => $record->type === 'income' ? 'success' : ($record->type === 'expense' ? 'danger' : 'warning'))
                    ->prefix(fn ($record) => $record->type === 'expense' ? '-' : '+'),

                TextColumn::make('currency')
                    ->label('العملة')
                    ->badge(),

                TextColumn::make('type')
                    ->label('النوع')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'expense' => 'مصروف',
                        'income' => 'دخل',
                        'saving' => 'ادخار',
                        default => $state,
                    })
                    ->color(fn (string $state): string => match ($state) {
                        'expense' => 'danger',
                        'income' => 'success',
                        'saving' => 'warning',
                        default => 'gray',
                    }),

                TextColumn::make('category.name_ar')
                    ->label('التصنيف')
                    ->placeholder('—')
                    ->badge(),

                TextColumn::make('source')
                    ->label('المصدر')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'manual' => 'يدوي',
                        'mock_bank' => 'بنك تجريبي',
                        'imported' => 'مستورد',
                        default => $state,
                    })
                    ->toggleable(),

                TextColumn::make('transaction_date')
                    ->label('التاريخ')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->defaultSort('transaction_date', 'desc')
            ->filters([
                SelectFilter::make('type')
                    ->label('النوع')
                    ->options([
                        'expense' => 'مصروف',
                        'income' => 'دخل',
                        'saving' => 'ادخار',
                    ]),

                SelectFilter::make('source')
                    ->label('المصدر')
                    ->options([
                        'manual' => 'يدوي',
                        'mock_bank' => 'بنك تجريبي',
                        'imported' => 'مستورد',
                    ]),

                SelectFilter::make('category_id')
                    ->label('التصنيف')
                    ->relationship('category', 'name_ar'),
            ])
            ->recordActions([
                ViewAction::make()->label('عرض'),
            ])
            ->headerActions([
                ExportAction::make()
                    ->label(__('waffer.actions.export'))
                    ->exporter(TransactionExporter::class),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    ExportBulkAction::make()
                        ->label(__('waffer.actions.export'))
                        ->exporter(TransactionExporter::class),
                ]),
            ]);
    }
}
