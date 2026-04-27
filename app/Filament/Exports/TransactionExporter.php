<?php

namespace App\Filament\Exports;

use App\Models\Transaction;
use Filament\Actions\Exports\ExportColumn;
use Filament\Actions\Exports\Exporter;
use Filament\Actions\Exports\Models\Export;

class TransactionExporter extends Exporter
{
    protected static ?string $model = Transaction::class;

    public static function getColumns(): array
    {
        return [
            ExportColumn::make('id')->label('ID'),
            ExportColumn::make('user.name')->label('User'),
            ExportColumn::make('user.phone')->label('Phone'),
            ExportColumn::make('category.name_ar')->label('التصنيف'),
            ExportColumn::make('category.name_en')->label('Category'),
            ExportColumn::make('type')->label('النوع'),
            ExportColumn::make('amount')->label('المبلغ'),
            ExportColumn::make('currency')->label('العملة'),
            ExportColumn::make('description')->label('الوصف'),
            ExportColumn::make('merchant')->label('الجهة'),
            ExportColumn::make('source')->label('المصدر'),
            ExportColumn::make('reference')->label('المرجع'),
            ExportColumn::make('transaction_date')->label('تاريخ المعاملة'),
            ExportColumn::make('created_at')->label('تاريخ الإنشاء'),
        ];
    }

    public static function getCompletedNotificationBody(Export $export): string
    {
        $body = 'تم تصدير '.number_format($export->successful_rows).' معاملة بنجاح.';

        if ($failedRowsCount = $export->getFailedRowsCount()) {
            $body .= ' فشل تصدير '.number_format($failedRowsCount).' صف.';
        }

        return $body;
    }
}
