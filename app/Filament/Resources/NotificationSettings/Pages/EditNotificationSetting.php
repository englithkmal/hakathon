<?php

namespace App\Filament\Resources\NotificationSettings\Pages;

use App\Filament\Resources\NotificationSettings\NotificationSettingResource;
use Filament\Actions\Action;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\EditRecord;
use Illuminate\Support\Facades\Artisan;

class EditNotificationSetting extends EditRecord
{
    protected static string $resource = NotificationSettingResource::class;

    public function getTitle(): string
    {
        return 'تعديل إعدادات: '.$this->record->label_ar;
    }

    protected function getHeaderActions(): array
    {
        return [
            Action::make('sendNow')
                ->label('إرسال الآن')
                ->icon('heroicon-o-paper-airplane')
                ->color('success')
                ->requiresConfirmation()
                ->modalHeading('إرسال إشعار فوري')
                ->modalDescription(fn () => "سيتم تنفيذ: {$this->record->fullCommand()}")
                ->action(function () {
                    try {
                        $exitCode = Artisan::call($this->record->command, array_merge(
                            $this->record->extra_config ?? [],
                            ['--force' => true],
                        ));

                        $output = trim(Artisan::output());

                        if ($exitCode === 0) {
                            Notification::make()
                                ->title('تم التنفيذ بنجاح')
                                ->success()
                                ->send();

                            $this->record->refresh();
                        } else {
                            Notification::make()
                                ->title('فشل التنفيذ')
                                ->body(mb_substr($output, 0, 300))
                                ->danger()
                                ->send();
                        }
                    } catch (\Throwable $e) {
                        Notification::make()
                            ->title('استثناء')
                            ->body($e->getMessage())
                            ->danger()
                            ->send();
                    }
                }),
        ];
    }

    protected function getRedirectUrl(): string
    {
        return $this->getResource()::getUrl('index');
    }
}
