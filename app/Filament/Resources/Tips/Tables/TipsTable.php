<?php

namespace App\Filament\Resources\Tips\Tables;

use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class TipsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('image')
                    ->label('')
                    ->square()
                    ->size(50),

                TextColumn::make('title_ar')
                    ->label('العنوان (ع)')
                    ->searchable()
                    ->wrap()
                    ->weight('bold'),

                TextColumn::make('title_en')
                    ->label('Title (EN)')
                    ->searchable()
                    ->toggleable(),

                TextColumn::make('category.name_ar')
                    ->label('التصنيف')
                    ->placeholder('—')
                    ->badge(),

                TextColumn::make('audience')
                    ->label('الجمهور')
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => match ($state) {
                        'all' => 'الجميع',
                        'spenders' => 'كثيري الصرف',
                        'savers' => 'الموفرون',
                        'beginners' => 'المبتدئون',
                        default => $state,
                    }),

                TextColumn::make('sort_order')
                    ->label('الترتيب')
                    ->sortable()
                    ->toggleable(),

                IconColumn::make('is_active')
                    ->label('مفعّلة')
                    ->boolean(),

                TextColumn::make('created_at')
                    ->label('تاريخ الإضافة')
                    ->dateTime('Y-m-d')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('sort_order')
            ->filters([
                SelectFilter::make('audience')
                    ->label('الجمهور')
                    ->options([
                        'all' => 'الجميع',
                        'spenders' => 'كثيري الصرف',
                        'savers' => 'الموفرون',
                        'beginners' => 'المبتدئون',
                    ]),

                SelectFilter::make('category_id')
                    ->label('التصنيف')
                    ->relationship('category', 'name_ar'),

                TernaryFilter::make('is_active')->label('الحالة'),
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
