<?php

namespace App\Filament\Resources\SavingGoals\Tables;

use App\Filament\Exports\SavingGoalExporter;
use App\Models\SavingGoal;
use App\Services\SavingGoalLinker;
use Filament\Actions\Action;
use Filament\Actions\ActionGroup;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\ExportAction;
use Filament\Actions\ExportBulkAction;
use Filament\Actions\ViewAction;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class SavingGoalsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('user.name')
                    ->label('المستخدم')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('title')
                    ->label('الهدف')
                    ->searchable()
                    ->weight('bold'),

                TextColumn::make('target_amount')
                    ->label('المبلغ المستهدف')
                    ->numeric(2)
                    ->sortable(),

                TextColumn::make('current_amount')
                    ->label('المبلغ الحالي')
                    ->numeric(2)
                    ->color('success'),

                TextColumn::make('progress_percentage')
                    ->label('% التقدم')
                    ->state(fn ($record) => $record->progress_percentage.'%')
                    ->color(fn ($record) => $record->progress_percentage >= 100 ? 'success' : ($record->progress_percentage >= 50 ? 'warning' : 'gray')),

                TextColumn::make('currency')
                    ->label('العملة')
                    ->badge()
                    ->toggleable(),

                TextColumn::make('deadline')
                    ->label('الموعد النهائي')
                    ->date('Y-m-d')
                    ->sortable()
                    ->placeholder('—'),

                TextColumn::make('status')
                    ->label('الحالة')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'active' => 'نشط',
                        'achieved' => 'محقق',
                        'paused' => 'متوقف',
                        'cancelled' => 'ملغي',
                        default => $state,
                    })
                    ->color(fn (string $state): string => match ($state) {
                        'active' => 'info',
                        'achieved' => 'success',
                        'paused' => 'warning',
                        'cancelled' => 'danger',
                        default => 'gray',
                    }),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('status')
                    ->label('الحالة')
                    ->options([
                        'active' => 'نشط',
                        'achieved' => 'محقق',
                        'paused' => 'متوقف',
                        'cancelled' => 'ملغي',
                    ]),
            ])
            ->recordActions([
                ActionGroup::make([
                    ViewAction::make()->label('عرض'),

                    Action::make('recompute')
                        ->label('إعادة حساب الرصيد')
                        ->icon('heroicon-o-arrow-path')
                        ->color('warning')
                        ->requiresConfirmation()
                        ->modalHeading('إعادة احتساب رصيد الهدف')
                        ->modalDescription('سيتم احتساب current_amount من مجموع المعاملات المرتبطة بهذا الهدف (transactions حيث type=saving). يُستخدم لو ظهر فرق بين الإيداعات والرصيد المعروض.')
                        ->modalSubmitActionLabel('إعادة الاحتساب')
                        ->action(function (SavingGoal $record, SavingGoalLinker $linker) {
                            $oldAmount = $record->current_amount;
                            $linker->recompute($record);
                            $record->refresh();

                            Notification::make()
                                ->title('تم إعادة الحساب')
                                ->body("الرصيد قبل: {$oldAmount} → بعد: {$record->current_amount}")
                                ->success()
                                ->send();
                        }),
                ])->iconButton(),
            ])
            ->headerActions([
                ExportAction::make()
                    ->label(__('waffer.actions.export'))
                    ->exporter(SavingGoalExporter::class),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    ExportBulkAction::make()
                        ->label(__('waffer.actions.export'))
                        ->exporter(SavingGoalExporter::class),
                ]),
            ]);
    }
}
