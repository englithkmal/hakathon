<?php

namespace App\Filament\Resources\MonthlySummaries\Pages;

use App\Filament\Resources\MonthlySummaries\MonthlySummaryResource;
use App\Models\MonthlySummary;
use App\Services\MonthlyCloser;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ViewRecord;

class ViewMonthlySummary extends ViewRecord
{
    protected static string $resource = MonthlySummaryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('recompute')
                ->label('إعادة الحساب (Force)')
                ->icon('heroicon-o-arrow-path')
                ->color('warning')
                ->requiresConfirmation()
                ->modalHeading('إعادة احتساب التقرير الشهري')
                ->modalDescription('سيتم إعادة قراءة كل المعاملات لهذه الفترة وتحديث الأرقام. الحقول المتعلقة بالتخصيص لن تتأثر.')
                ->modalSubmitActionLabel('إعادة الحساب')
                ->action(function (MonthlySummary $record, MonthlyCloser $closer) {
                    $summary = $closer->closeUserMonth(
                        $record->user,
                        (int) $record->year,
                        (int) $record->month,
                        MonthlySummary::CLOSED_BY_MANUAL,
                        force: true,
                    );

                    Notification::make()
                        ->title('تم إعادة الحساب')
                        ->body($summary
                            ? "الدخل: {$summary->total_income} | المصروف: {$summary->total_expenses}"
                            : 'لا توجد بيانات.')
                        ->success()
                        ->send();

                    $this->refreshFormData(['*']);
                }),
        ];
    }
}
