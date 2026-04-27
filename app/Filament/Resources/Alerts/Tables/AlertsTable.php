<?php

namespace App\Filament\Resources\Alerts\Tables;

use Filament\Actions\ViewAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class AlertsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('user.name')
                    ->label('المستخدم')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('title_ar')
                    ->label('العنوان')
                    ->searchable()
                    ->wrap()
                    ->weight('bold'),

                TextColumn::make('type')
                    ->label('النوع')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'threshold_50' => 'تنبيه 50%',
                        'threshold_80' => 'تنبيه 80%',
                        'threshold_100' => 'تنبيه 100%',
                        'exceeded' => 'تجاوز الميزانية',
                        'goal_progress' => 'تقدم الهدف',
                        'goal_achieved' => 'تحقيق الهدف',
                        'low_balance' => 'رصيد منخفض',
                        'tip' => 'نصيحة',
                        'system' => 'نظام',
                        default => $state,
                    }),

                TextColumn::make('severity')
                    ->label('الأهمية')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'info' => 'معلومة',
                        'warning' => 'تحذير',
                        'critical' => 'خطر',
                        default => $state,
                    })
                    ->color(fn (string $state): string => match ($state) {
                        'info' => 'info',
                        'warning' => 'warning',
                        'critical' => 'danger',
                        default => 'gray',
                    }),

                IconColumn::make('is_read')
                    ->label('مقروء')
                    ->boolean(),

                TextColumn::make('created_at')
                    ->label('التاريخ')
                    ->dateTime('Y-m-d H:i')
                    ->sortable(),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                SelectFilter::make('type')
                    ->label('النوع')
                    ->options([
                        'threshold_50' => 'تنبيه 50%',
                        'threshold_80' => 'تنبيه 80%',
                        'threshold_100' => 'تنبيه 100%',
                        'exceeded' => 'تجاوز الميزانية',
                        'goal_progress' => 'تقدم الهدف',
                        'goal_achieved' => 'تحقيق الهدف',
                        'low_balance' => 'رصيد منخفض',
                        'tip' => 'نصيحة',
                        'system' => 'نظام',
                    ]),

                SelectFilter::make('severity')
                    ->label('الأهمية')
                    ->options([
                        'info' => 'معلومة',
                        'warning' => 'تحذير',
                        'critical' => 'خطر',
                    ]),

                TernaryFilter::make('is_read')->label('مقروء'),
            ])
            ->recordActions([
                ViewAction::make()->label('عرض'),
            ]);
    }
}
