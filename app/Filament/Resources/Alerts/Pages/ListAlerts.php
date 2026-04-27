<?php

namespace App\Filament\Resources\Alerts\Pages;

use App\Filament\Resources\Alerts\AlertResource;
use App\Models\Alert;
use App\Models\User;
use App\Services\FcmService;
use Filament\Actions\Action;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Notifications\Notification;
use Filament\Resources\Pages\ListRecords;
use Illuminate\Support\Facades\Log;

class ListAlerts extends ListRecords
{
    protected static string $resource = AlertResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Action::make('sendManual')
                ->label('إرسال إشعار يدوي')
                ->icon('heroicon-o-paper-airplane')
                ->color('primary')
                ->modalHeading('إرسال إشعار يدوي')
                ->modalSubmitActionLabel('إرسال')
                ->modalWidth('lg')
                ->schema([
                    Select::make('audience')
                        ->label('الجمهور')
                        ->options([
                            'all'      => 'كل المستخدمين النشطين',
                            'specific' => 'مستخدمون محددون',
                        ])
                        ->default('all')
                        ->required()
                        ->live()
                        ->native(false),

                    Select::make('user_ids')
                        ->label('اختر المستخدمين')
                        ->multiple()
                        ->searchable()
                        ->preload()
                        ->options(fn () => User::where('is_admin', false)
                            ->where('is_active', true)
                            ->orderBy('name')
                            ->pluck('name', 'id'))
                        ->visible(fn ($get) => $get('audience') === 'specific')
                        ->required(fn ($get) => $get('audience') === 'specific'),

                    Select::make('severity')
                        ->label('الأهمية')
                        ->options([
                            'info'     => 'معلومة',
                            'warning'  => 'تحذير',
                            'critical' => 'خطر',
                        ])
                        ->default('info')
                        ->required()
                        ->native(false),

                    TextInput::make('title_ar')
                        ->label('العنوان (عربي)')
                        ->required()
                        ->maxLength(120),

                    TextInput::make('title_en')
                        ->label('Title (EN)')
                        ->required()
                        ->maxLength(120),

                    Textarea::make('message_ar')
                        ->label('الرسالة (عربي)')
                        ->required()
                        ->rows(3)
                        ->maxLength(500),

                    Textarea::make('message_en')
                        ->label('Message (EN)')
                        ->required()
                        ->rows(3)
                        ->maxLength(500),

                    Toggle::make('send_push')
                        ->label('إرسال Push Notification (FCM)')
                        ->default(true)
                        ->helperText('إن أُلغي، تُنشأ السجلات في قائمة الإشعارات داخل التطبيق فقط دون push.'),
                ])
                ->action(function (array $data) {
                    $userIds = $data['audience'] === 'all'
                        ? User::where('is_admin', false)->where('is_active', true)->pluck('id')->all()
                        : $data['user_ids'];

                    if (empty($userIds)) {
                        Notification::make()
                            ->title('لا يوجد مستخدمون لإرسال الإشعار إليهم.')
                            ->warning()
                            ->send();

                        return;
                    }

                    $now = now();
                    $rows = [];
                    foreach ($userIds as $uid) {
                        $rows[] = [
                            'user_id'    => $uid,
                            'type'       => 'system',
                            'severity'   => $data['severity'],
                            'title_ar'   => $data['title_ar'],
                            'title_en'   => $data['title_en'],
                            'message_ar' => $data['message_ar'],
                            'message_en' => $data['message_en'],
                            'payload'    => json_encode(['source' => 'manual_admin'], JSON_UNESCAPED_UNICODE),
                            'is_read'    => false,
                            'created_at' => $now,
                            'updated_at' => $now,
                        ];
                    }

                    Alert::insert($rows);

                    $sent = 0;
                    $failed = 0;

                    if (! empty($data['send_push'])) {
                        try {
                            /** @var FcmService $fcm */
                            $fcm = app(FcmService::class);
                            $users = User::whereIn('id', $userIds)->get();

                            $stats = $fcm->sendToUsers($users, [
                                'title_ar' => $data['title_ar'],
                                'title_en' => $data['title_en'],
                                'body_ar'  => $data['message_ar'],
                                'body_en'  => $data['message_en'],
                                'data'     => [
                                    'type'         => 'manual_admin',
                                    'severity'     => $data['severity'],
                                    'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                                ],
                            ]);

                            $sent = $stats['sent'] ?? 0;
                            $failed = $stats['failed'] ?? 0;
                        } catch (\Throwable $e) {
                            Log::error('Manual notification FCM failed', ['error' => $e->getMessage()]);

                            Notification::make()
                                ->title('تم حفظ الإشعار، لكن فشل الـ Push')
                                ->body($e->getMessage())
                                ->warning()
                                ->send();

                            return;
                        }
                    }

                    Notification::make()
                        ->title('تم الإرسال بنجاح')
                        ->body(sprintf(
                            'تم إنشاء %d سجل، Push: %d نجح / %d فشل.',
                            count($userIds),
                            $sent,
                            $failed
                        ))
                        ->success()
                        ->send();
                }),
        ];
    }
}
