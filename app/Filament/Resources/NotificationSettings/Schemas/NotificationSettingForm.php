<?php

namespace App\Filament\Resources\NotificationSettings\Schemas;

use Filament\Forms\Components\KeyValue;
use Filament\Forms\Components\Placeholder;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\TimePicker;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;
use Illuminate\Support\HtmlString;

class NotificationSettingForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                Section::make('التعريف')
                    ->columns(2)
                    ->schema([
                        TextInput::make('label_ar')
                            ->label('الاسم (عربي)')
                            ->required(),
                        TextInput::make('label_en')
                            ->label('Name (EN)')
                            ->required(),
                        TextInput::make('description_ar')
                            ->label('وصف مختصر (عربي)')
                            ->columnSpanFull(),
                        TextInput::make('description_en')
                            ->label('Description (EN)')
                            ->columnSpanFull(),
                        TextInput::make('command')
                            ->label('Artisan Command')
                            ->disabled()
                            ->dehydrated(false)
                            ->columnSpanFull()
                            ->helperText('لا يمكن تغيير اسم الكوماند من اللوحة.'),
                    ]),

                Section::make('الجدولة')
                    ->columns(3)
                    ->schema([
                        Toggle::make('is_enabled')
                            ->label('تفعيل الإرسال التلقائي')
                            ->onColor('success')
                            ->offColor('danger')
                            ->columnSpanFull(),

                        Select::make('schedule_frequency')
                            ->label('التكرار')
                            ->options([
                                'daily' => 'يومياً',
                                'monthly' => 'شهرياً',
                                'manual' => 'يدوي فقط (لا جدولة)',
                            ])
                            ->required()
                            ->native(false)
                            ->live(),

                        TimePicker::make('schedule_time')
                            ->label('وقت الإرسال (Asia/Riyadh)')
                            ->seconds(false)
                            ->hoursStep(1)
                            ->minutesStep(5)
                            ->visible(fn ($get) => $get('schedule_frequency') !== 'manual'),

                        TextInput::make('schedule_day_of_month')
                            ->label('يوم الشهر')
                            ->numeric()
                            ->minValue(1)
                            ->maxValue(28)
                            ->visible(fn ($get) => $get('schedule_frequency') === 'monthly'),
                    ]),

                Section::make('إعدادات إضافية')
                    ->description('قِيَم تُمرَّر للأمر كـ --option=value')
                    ->collapsed()
                    ->schema([
                        KeyValue::make('extra_config')
                            ->label('Options')
                            ->keyLabel('Option')
                            ->valueLabel('Value')
                            ->reorderable()
                            ->addable()
                            ->deletable()
                            ->columnSpanFull(),
                    ]),

                Section::make('آخر تشغيل')
                    ->collapsed()
                    ->schema([
                        Placeholder::make('last_run_at')
                            ->label('وقت آخر تشغيل')
                            ->content(fn ($record) => $record?->last_run_at?->diffForHumans() ?? '— لم يُشغَّل بعد —'),
                        Placeholder::make('last_run_status')
                            ->label('الحالة')
                            ->content(fn ($record) => match ($record?->last_run_status) {
                                'success' => new HtmlString('<span style="color:#16a34a;font-weight:600">✓ نجح</span>'),
                                'failed'  => new HtmlString('<span style="color:#dc2626;font-weight:600">✗ فشل</span>'),
                                'skipped' => new HtmlString('<span style="color:#ca8a04;font-weight:600">⏭ تم التخطي</span>'),
                                default   => '—',
                            }),
                        Placeholder::make('last_run_stats_pretty')
                            ->label('تفاصيل النتيجة')
                            ->content(fn ($record) => $record?->last_run_stats
                                ? new HtmlString('<pre style="background:#f1f5f9;padding:12px;border-radius:8px;font-size:12px;direction:ltr">'
                                    .e(json_encode($record->last_run_stats, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE))
                                    .'</pre>')
                                : '—'),
                    ]),
            ]);
    }
}
