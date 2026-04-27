<?php

namespace App\Filament\Resources\Tips\Schemas;

use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class TipForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('المحتوى بالعربية')
                    ->schema([
                        TextInput::make('title_ar')
                            ->label('العنوان')
                            ->required()
                            ->maxLength(255),

                        Textarea::make('content_ar')
                            ->label('المحتوى')
                            ->required()
                            ->rows(4)
                            ->maxLength(2000),
                    ]),

                Section::make('Content (English)')
                    ->schema([
                        TextInput::make('title_en')
                            ->label('Title')
                            ->required()
                            ->maxLength(255),

                        Textarea::make('content_en')
                            ->label('Content')
                            ->required()
                            ->rows(4)
                            ->maxLength(2000),
                    ]),

                Section::make('الإعدادات')
                    ->columns(2)
                    ->schema([
                        Select::make('category_id')
                            ->label('التصنيف المرتبط')
                            ->relationship('category', 'name_ar')
                            ->searchable()
                            ->preload()
                            ->placeholder('عام (بدون تصنيف)'),

                        Select::make('audience')
                            ->label('الجمهور المستهدف')
                            ->options([
                                'all' => 'الجميع',
                                'spenders' => 'كثيري الصرف',
                                'savers' => 'الموفرون',
                                'beginners' => 'المبتدئون',
                            ])
                            ->required()
                            ->default('all')
                            ->native(false),

                        TextInput::make('icon')
                            ->label('الأيقونة')
                            ->placeholder('heroicon-o-light-bulb'),

                        TextInput::make('sort_order')
                            ->label('الترتيب')
                            ->numeric()
                            ->default(0),

                        FileUpload::make('image')
                            ->label('الصورة')
                            ->image()
                            ->directory('tips')
                            ->columnSpanFull(),

                        Toggle::make('is_active')
                            ->label('مفعّلة')
                            ->default(true)
                            ->columnSpanFull(),
                    ]),
            ]);
    }
}
