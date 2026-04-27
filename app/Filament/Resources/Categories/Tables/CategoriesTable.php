<?php

namespace App\Filament\Resources\Categories\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\ColorColumn;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class CategoriesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('sort_order')
                    ->label('#')
                    ->sortable(),

                ColorColumn::make('color')
                    ->label(''),

                TextColumn::make('name_ar')
                    ->label('الاسم (ع)')
                    ->searchable()
                    ->weight('bold')
                    ->sortable(),

                TextColumn::make('name_en')
                    ->label('Name (EN)')
                    ->searchable()
                    ->toggleable(),

                TextColumn::make('slug')
                    ->label('المعرّف')
                    ->searchable()
                    ->toggleable(isToggledHiddenByDefault: true),

                TextColumn::make('type')
                    ->label('النوع')
                    ->badge()
                    ->color(fn (string $state): string => match ($state) {
                        'expense' => 'danger',
                        'income' => 'success',
                        'saving' => 'warning',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'expense' => 'مصروف',
                        'income' => 'دخل',
                        'saving' => 'ادخار',
                        default => $state,
                    }),

                TextColumn::make('user.name')
                    ->label('المستخدم')
                    ->placeholder('عام')
                    ->toggleable(),

                IconColumn::make('is_default')
                    ->label('افتراضي')
                    ->boolean(),

                IconColumn::make('is_active')
                    ->label('مفعّل')
                    ->boolean(),
            ])
            ->defaultSort('sort_order')
            ->filters([
                SelectFilter::make('type')
                    ->label('النوع')
                    ->options([
                        'expense' => 'مصروف',
                        'income' => 'دخل',
                        'saving' => 'ادخار',
                    ]),
                TernaryFilter::make('is_default')->label('افتراضي'),
                TernaryFilter::make('is_active')->label('مفعّل'),
            ])
            ->recordActions([
                EditAction::make()->label('تعديل'),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    DeleteBulkAction::make()->label('حذف المحدد'),
                ]),
            ]);
    }
}
