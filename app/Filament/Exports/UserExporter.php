<?php

namespace App\Filament\Exports;

use App\Models\User;
use Filament\Actions\Exports\ExportColumn;
use Filament\Actions\Exports\Exporter;
use Filament\Actions\Exports\Models\Export;

class UserExporter extends Exporter
{
    protected static ?string $model = User::class;

    public static function getColumns(): array
    {
        return [
            ExportColumn::make('id')->label('ID'),
            ExportColumn::make('name')->label('الاسم'),
            ExportColumn::make('phone')->label('الهاتف'),
            ExportColumn::make('email')->label('البريد'),
            ExportColumn::make('monthly_income')->label('الدخل الشهري'),
            ExportColumn::make('currency')->label('العملة'),
            ExportColumn::make('language')->label('اللغة'),
            ExportColumn::make('is_admin')->label('مدير')
                ->formatStateUsing(fn ($state) => $state ? 'نعم' : 'لا'),
            ExportColumn::make('is_active')->label('مفعّل')
                ->formatStateUsing(fn ($state) => $state ? 'نعم' : 'لا'),
            ExportColumn::make('phone_verified_at')->label('وقت التحقق من الهاتف'),
            ExportColumn::make('created_at')->label('تاريخ التسجيل'),
        ];
    }

    public static function getCompletedNotificationBody(Export $export): string
    {
        return 'تم تصدير '.number_format($export->successful_rows).' مستخدم بنجاح.';
    }
}
