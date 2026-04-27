<?php

namespace App\Filament\Resources\Categories\Schemas;

use Filament\Forms\Components\ColorPicker;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Illuminate\Support\Str;

class CategoryForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('بيانات التصنيف')
                    ->columns(2)
                    ->schema([
                        TextInput::make('name_ar')
                            ->label('الاسم بالعربية')
                            ->required()
                            ->maxLength(255)
                            ->live(onBlur: true)
                            ->afterStateUpdated(function ($state, callable $set, $get) {
                                if (! $get('slug')) {
                                    $set('slug', Str::slug($state));
                                }
                            }),

                        TextInput::make('name_en')
                            ->label('Name (English)')
                            ->required()
                            ->maxLength(255)
                            ->live(onBlur: true)
                            ->afterStateUpdated(function ($state, callable $set, $get) {
                                if (! $get('slug')) {
                                    $set('slug', Str::slug($state));
                                }
                            }),

                        TextInput::make('slug')
                            ->label('المعرّف (slug)')
                            ->maxLength(255)
                            ->unique(ignoreRecord: true)
                            ->helperText('يُستخدم للربط البرمجي'),

                        Select::make('type')
                            ->label('النوع')
                            ->options([
                                'expense' => 'مصروف',
                                'income' => 'دخل',
                                'saving' => 'ادخار',
                            ])
                            ->required()
                            ->default('expense')
                            ->native(false),
                    ]),

                Section::make('المظهر')
                    ->columns(3)
                    ->schema([
                        TextInput::make('icon')
                            ->label('الأيقونة')
                            ->placeholder('heroicon-o-cake')
                            ->helperText('اسم أيقونة Heroicon'),

                        ColorPicker::make('color')
                            ->label('اللون'),

                        TextInput::make('sort_order')
                            ->label('الترتيب')
                            ->numeric()
                            ->default(0)
                            ->minValue(0),
                    ]),

                Section::make('الإعدادات')
                    ->columns(2)
                    ->schema([
                        Toggle::make('is_default')
                            ->label('تصنيف افتراضي للنظام')
                            ->helperText('يظهر لجميع المستخدمين'),

                        Toggle::make('is_active')
                            ->label('مفعّل')
                            ->default(true),
                    ]),
            ]);
    }
}
