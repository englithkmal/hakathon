<?php

namespace App\Filament\Exports;

use App\Models\SavingGoal;
use Filament\Actions\Exports\ExportColumn;
use Filament\Actions\Exports\Exporter;
use Filament\Actions\Exports\Models\Export;

class SavingGoalExporter extends Exporter
{
    protected static ?string $model = SavingGoal::class;

    public static function getColumns(): array
    {
        return [
            ExportColumn::make('id')->label('ID'),
            ExportColumn::make('user.name')->label('المستخدم'),
            ExportColumn::make('user.phone')->label('الهاتف'),
            ExportColumn::make('title')->label('العنوان'),
            ExportColumn::make('description')->label('الوصف'),
            ExportColumn::make('target_amount')->label('المبلغ المستهدف'),
            ExportColumn::make('current_amount')->label('المبلغ الحالي'),
            ExportColumn::make('currency')->label('العملة'),
            ExportColumn::make('deadline')->label('الموعد النهائي'),
            ExportColumn::make('status')->label('الحالة'),
            ExportColumn::make('created_at')->label('تاريخ الإنشاء'),
        ];
    }

    public static function getCompletedNotificationBody(Export $export): string
    {
        return 'تم تصدير '.number_format($export->successful_rows).' هدف بنجاح.';
    }
}
