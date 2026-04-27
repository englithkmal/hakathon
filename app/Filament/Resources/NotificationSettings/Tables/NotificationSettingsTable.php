<?php

namespace App\Filament\Resources\NotificationSettings\Tables;

use App\Models\NotificationSetting;
use Filament\Actions\Action;
use Filament\Actions\EditAction;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Columns\ToggleColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Artisan;

class NotificationSettingsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('label_ar')
                    ->label('الإشعار')
                    ->weight('bold')
                    ->wrap()
                    ->description(fn (NotificationSetting $r) => $r->description_ar)
                    ->searchable(['label_ar', 'label_en', 'description_ar', 'description_en']),

                TextColumn::make('schedule_frequency')
                    ->label('التكرار')
                    ->badge()
                    ->color(fn (string $state) => match ($state) {
                        'daily' => 'info',
                        'monthly' => 'warning',
                        'manual' => 'gray',
                        default => 'gray',
                    })
                    ->formatStateUsing(fn (string $state) => match ($state) {
                        'daily' => 'يومياً',
                        'monthly' => 'شهرياً',
                        'manual' => 'يدوي',
                        default => $state,
                    }),

                TextColumn::make('schedule_time')
                    ->label('الوقت')
                    ->formatStateUsing(fn ($state, NotificationSetting $r) => $r->schedule_time
                        ? $r->schedule_time->format('H:i')
                        : '—')
                    ->alignCenter(),

                ToggleColumn::make('is_enabled')
                    ->label('مفعّل')
                    ->onColor('success')
                    ->offColor('danger'),

                TextColumn::make('last_run_at')
                    ->label('آخر تشغيل')
                    ->formatStateUsing(fn ($state) => $state ? $state->diffForHumans() : '— لم يشتغل بعد —')
                    ->color(fn ($state) => $state ? null : 'gray')
                    ->sortable(),

                IconColumn::make('last_run_status')
                    ->label('الحالة')
                    ->icon(fn (?string $state) => match ($state) {
                        'success' => 'heroicon-o-check-circle',
                        'failed'  => 'heroicon-o-x-circle',
                        'skipped' => 'heroicon-o-minus-circle',
                        default   => 'heroicon-o-clock',
                    })
                    ->color(fn (?string $state) => match ($state) {
                        'success' => 'success',
                        'failed'  => 'danger',
                        'skipped' => 'warning',
                        default   => 'gray',
                    })
                    ->tooltip(fn (?string $state) => $state ?? 'لم يُشغَّل بعد'),
            ])
            ->defaultSort('id')
            ->paginated(false)
            ->filters([
                TernaryFilter::make('is_enabled')->label('الحالة'),
            ])
            ->recordActions([
                Action::make('sendNow')
                    ->label('إرسال الآن')
                    ->icon('heroicon-o-paper-airplane')
                    ->color('success')
                    ->requiresConfirmation()
                    ->modalHeading('إرسال إشعار فوري')
                    ->modalDescription(fn (NotificationSetting $r) => "سيتم تنفيذ الكوماند: {$r->fullCommand()} الآن (ولو كان معطّلاً).")
                    ->modalSubmitActionLabel('نعم، أرسِل الآن')
                    ->action(function (NotificationSetting $record) {
                        try {
                            $exitCode = Artisan::call($record->command, array_merge(
                                $record->extra_config ?? [],
                                ['--force' => true],
                            ));

                            $output = trim(Artisan::output());

                            if ($exitCode === 0) {
                                Notification::make()
                                    ->title('تم التنفيذ بنجاح')
                                    ->body($record->label_ar)
                                    ->success()
                                    ->send();
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

                EditAction::make()->label('تعديل'),
            ])
            ->toolbarActions([])
            ->emptyStateHeading('لا توجد إعدادات إشعارات.')
            ->emptyStateDescription('شغِّل: php artisan db:seed --class=NotificationSettingSeeder');
    }
}
