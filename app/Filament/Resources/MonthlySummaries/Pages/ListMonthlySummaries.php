<?php

namespace App\Filament\Resources\MonthlySummaries\Pages;

use App\Filament\Resources\MonthlySummaries\MonthlySummaryResource;
use App\Models\MonthlySummary;
use App\Models\User;
use App\Services\MonthlyCloser;
use Carbon\Carbon;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Toggle;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;

class ListMonthlySummaries extends ListRecords
{
    protected static string $resource = MonthlySummaryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('closeMonth')
                ->label('إغلاق شهر يدوياً')
                ->icon('heroicon-o-lock-closed')
                ->color('primary')
                ->modalHeading('إغلاق شهر يدوياً (Manual Close)')
                ->modalDescription('سيتم إنشاء snapshot شهري للمستخدم المحدد. لو الـ snapshot موجود مسبقاً يُتجاهل (إلا إذا فعّلت Force).')
                ->modalSubmitActionLabel('إغلاق الآن')
                ->modalWidth('lg')
                ->schema([
                    Select::make('user_id')
                        ->label('المستخدم')
                        ->options(fn () => User::where('is_admin', false)
                            ->orderBy('name')
                            ->pluck('name', 'id'))
                        ->searchable()
                        ->preload()
                        ->required(),

                    Select::make('year')
                        ->label('السنة')
                        ->options(function () {
                            $current = (int) now()->year;
                            $years = range($current - 2, $current);

                            return array_combine($years, array_map('strval', $years));
                        })
                        ->default((int) now()->subMonth()->year)
                        ->required(),

                    Select::make('month')
                        ->label('الشهر')
                        ->options([
                            1 => 'يناير', 2 => 'فبراير', 3 => 'مارس', 4 => 'أبريل',
                            5 => 'مايو', 6 => 'يونيو', 7 => 'يوليو', 8 => 'أغسطس',
                            9 => 'سبتمبر', 10 => 'أكتوبر', 11 => 'نوفمبر', 12 => 'ديسمبر',
                        ])
                        ->default((int) now()->subMonth()->month)
                        ->required(),

                    Toggle::make('force')
                        ->label('إعادة احتساب لو كان موجوداً (Force)')
                        ->helperText('استخدمه فقط للأشهر المغلقة سابقاً التي تحتاج إعادة بناء بسبب تغيّر بيانات.')
                        ->default(false),
                ])
                ->action(function (array $data, MonthlyCloser $closer) {
                    $user = User::find($data['user_id']);
                    if (! $user) {
                        Notification::make()->title('المستخدم غير موجود')->danger()->send();

                        return;
                    }

                    $summary = $closer->closeUserMonth(
                        $user,
                        (int) $data['year'],
                        (int) $data['month'],
                        MonthlySummary::CLOSED_BY_MANUAL,
                        force: (bool) ($data['force'] ?? false),
                    );

                    if (! $summary) {
                        Notification::make()
                            ->title('لا توجد بيانات للإغلاق')
                            ->body('لا توجد ميزانية ولا معاملات لهذا الشهر — تخطّي الإنشاء.')
                            ->warning()
                            ->send();

                        return;
                    }

                    $label = Carbon::createFromDate($summary->year, $summary->month, 1)
                        ->locale('ar')
                        ->translatedFormat('F Y');

                    Notification::make()
                        ->title("تم إغلاق {$label}")
                        ->body(sprintf(
                            'الدخل: %s | المصروف: %s | الوفر: %s%s',
                            number_format((float) $summary->total_income, 2),
                            number_format((float) $summary->total_expenses, 2),
                            number_format((float) $summary->unallocated_savings, 2),
                            ! empty($data['force']) ? ' (Force)' : ''
                        ))
                        ->success()
                        ->send();
                }),
        ];
    }
}
