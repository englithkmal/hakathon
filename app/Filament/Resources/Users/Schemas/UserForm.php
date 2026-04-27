<?php

namespace App\Filament\Resources\Users\Schemas;

use Filament\Forms\Components\DateTimePicker;
use Filament\Forms\Components\FileUpload;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Illuminate\Support\Facades\Hash;

class UserForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('المعلومات الأساسية')
                    ->columns(2)
                    ->schema([
                        TextInput::make('name')
                            ->label('الاسم')
                            ->required()
                            ->maxLength(255),

                        TextInput::make('phone')
                            ->label('رقم الهاتف')
                            ->tel()
                            ->required()
                            ->unique(ignoreRecord: true)
                            ->maxLength(20),

                        TextInput::make('email')
                            ->label('البريد الإلكتروني')
                            ->email()
                            ->unique(ignoreRecord: true)
                            ->maxLength(255),

                        TextInput::make('password')
                            ->label('كلمة المرور')
                            ->password()
                            ->revealable()
                            ->dehydrateStateUsing(fn (?string $state): ?string => filled($state) ? Hash::make($state) : null)
                            ->dehydrated(fn (?string $state): bool => filled($state))
                            ->required(fn (string $operation): bool => $operation === 'create')
                            ->helperText('اتركها فارغة للإبقاء على الحالية عند التعديل'),

                        FileUpload::make('avatar')
                            ->label('الصورة')
                            ->image()
                            ->avatar()
                            ->directory('avatars')
                            ->columnSpanFull(),
                    ]),

                Section::make('الإعدادات المالية')
                    ->columns(3)
                    ->schema([
                        TextInput::make('monthly_income')
                            ->label('الدخل الشهري')
                            ->numeric()
                            ->minValue(0)
                            ->prefix('₪'),

                        Select::make('currency')
                            ->label('العملة')
                            ->options([
                                'SAR' => 'ريال سعودي (SAR)',
                                'JOD' => 'دينار أردني (JOD)',
                                'USD' => 'دولار أمريكي (USD)',
                                'AED' => 'درهم إماراتي (AED)',
                                'EUR' => 'يورو (EUR)',
                            ])
                            ->required()
                            ->default('SAR')
                            ->native(false),

                        Select::make('language')
                            ->label('اللغة')
                            ->options([
                                'ar' => 'العربية',
                                'en' => 'English',
                            ])
                            ->required()
                            ->default('ar')
                            ->native(false),
                    ]),

                Section::make('الحالة والصلاحيات')
                    ->columns(2)
                    ->schema([
                        Toggle::make('is_admin')
                            ->label('مدير النظام')
                            ->helperText('يمنح صلاحية الوصول إلى لوحة التحكم'),

                        Toggle::make('is_active')
                            ->label('الحساب مفعّل')
                            ->default(true),

                        DateTimePicker::make('phone_verified_at')
                            ->label('تاريخ التحقق من الهاتف')
                            ->native(false),

                        DateTimePicker::make('email_verified_at')
                            ->label('تاريخ التحقق من البريد')
                            ->native(false),
                    ]),
            ]);
    }
}
