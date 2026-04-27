<?php

namespace App\Filament\Exports;

use App\Models\Budget;
use Filament\Actions\Exports\ExportColumn;
use Filament\Actions\Exports\Exporter;
use Filament\Actions\Exports\Models\Export;

class BudgetExporter extends Exporter
{
    protected static ?string $model = Budget::class;

    public static function getColumns(): array
    {
        return [
            ExportColumn::make('id')->label('ID'),
            ExportColumn::make('user.name')->label('المستخدم'),
            ExportColumn::make('user.phone')->label('الهاتف'),
            ExportColumn::make('month')->label('الشهر'),
            ExportColumn::make('year')->label('السنة'),
            ExportColumn::make('total_income')->label('الدخل الإجمالي'),
            ExportColumn::make('total_amount')->label('إجمالي الميزانية'),
            ExportColumn::make('total_spent')->label('إجمالي المصروف'),
            ExportColumn::make('currency')->label('العملة'),
            ExportColumn::make('status')->label('الحالة'),
            ExportColumn::make('created_at')->label('تاريخ الإنشاء'),
        ];
    }

    public static function getCompletedNotificationBody(Export $export): string
    {
        return 'تم تصدير '.number_format($export->successful_rows).' ميزانية بنجاح.';
    }
}
