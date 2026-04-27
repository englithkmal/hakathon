<?php

namespace App\Filament\Resources\Users\Tables;

use App\Filament\Exports\UserExporter;
use App\Models\Alert;
use App\Models\User;
use App\Services\FcmService;
use App\Services\MockBankService;
use Filament\Actions\Action;
use Filament\Actions\ActionGroup;
use Filament\Actions\BulkAction;
use Filament\Actions\BulkActionGroup;
use Filament\Actions\DeleteBulkAction;
use Filament\Actions\EditAction;
use Filament\Actions\ExportAction;
use Filament\Actions\ExportBulkAction;
use Illuminate\Database\Eloquent\Collection;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\ImageColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class UsersTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->columns([
                ImageColumn::make('avatar')
                    ->label('')
                    ->circular()
                    ->defaultImageUrl(fn ($record): string => 'https://ui-avatars.com/api/?name='.urlencode($record->name).'&color=FFFFFF&background=F59E0B'),

                TextColumn::make('name')
                    ->label(__('waffer.fields.name'))
                    ->searchable()
                    ->sortable()
                    ->weight('bold'),

                TextColumn::make('phone')
                    ->label(__('waffer.fields.phone'))
                    ->searchable()
                    ->copyable(),

                TextColumn::make('email')
                    ->label(__('waffer.fields.email'))
                    ->searchable()
                    ->toggleable(),

                TextColumn::make('monthly_income')
                    ->label(__('waffer.fields.monthly_income'))
                    ->numeric(2)
                    ->sortable()
                    ->suffix(fn ($record) => ' '.$record->currency)
                    ->placeholder('—'),

                TextColumn::make('currency')
                    ->label(__('waffer.fields.currency'))
                    ->badge()
                    ->toggleable(),

                TextColumn::make('language')
                    ->label(__('waffer.fields.language'))
                    ->badge()
                    ->formatStateUsing(fn (string $state): string => $state === 'ar' ? 'العربية' : 'English')
                    ->color(fn (string $state): string => $state === 'ar' ? 'success' : 'info')
                    ->toggleable(),

                IconColumn::make('is_admin')
                    ->label(__('waffer.fields.is_admin'))
                    ->boolean()
                    ->sortable(),

                IconColumn::make('is_active')
                    ->label(__('waffer.fields.is_active'))
                    ->boolean()
                    ->sortable(),

                TextColumn::make('active_device_tokens_count')
                    ->label(__('waffer.fields.active_devices'))
                    ->counts('activeDeviceTokens')
                    ->badge()
                    ->color(fn ($state) => $state > 0 ? 'success' : 'gray')
                    ->toggleable(),

                TextColumn::make('created_at')
                    ->label(__('waffer.fields.created_at'))
                    ->dateTime('Y-m-d')
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->defaultSort('created_at', 'desc')
            ->filters([
                TernaryFilter::make('is_admin')
                    ->label(__('waffer.fields.is_admin')),

                TernaryFilter::make('is_active')
                    ->label(__('waffer.fields.is_active')),

                SelectFilter::make('language')
                    ->label(__('waffer.fields.language'))
                    ->options([
                        'ar' => 'العربية',
                        'en' => 'English',
                    ]),

                SelectFilter::make('currency')
                    ->label(__('waffer.fields.currency'))
                    ->options([
                        'SAR' => 'SAR',
                        'JOD' => 'JOD',
                        'USD' => 'USD',
                        'AED' => 'AED',
                        'EUR' => 'EUR',
                    ]),
            ])
            ->recordActions([
                ActionGroup::make([
                    EditAction::make(),

                    Action::make('importMockData')
                        ->label(__('waffer.actions.import_mock_data'))
                        ->icon('heroicon-o-arrow-down-tray')
                        ->color('info')
                        ->requiresConfirmation()
                        ->modalDescription(__('waffer.actions.import_mock_data_confirm'))
                        ->visible(fn (User $record) => ! $record->is_admin)
                        ->action(function (User $record, MockBankService $service) {
                            $result = $service->importForUser($record, clearExisting: true);

                            Notification::make()
                                ->title(__('waffer.actions.mock_imported'))
                                ->body($result['count'].' معاملة')
                                ->success()
                                ->send();
                        }),

                    Action::make('clearMockData')
                        ->label(__('waffer.actions.clear_mock_data'))
                        ->icon('heroicon-o-trash')
                        ->color('danger')
                        ->requiresConfirmation()
                        ->visible(fn (User $record) => ! $record->is_admin)
                        ->action(function (User $record, MockBankService $service) {
                            $deleted = $service->clearMockData($record);

                            Notification::make()
                                ->title('تم الحذف')
                                ->body($deleted.' معاملة')
                                ->warning()
                                ->send();
                        }),

                    Action::make('sendNotification')
                        ->label(__('waffer.actions.send_notification'))
                        ->icon('heroicon-o-bell-alert')
                        ->color('warning')
                        ->modalHeading(__('waffer.actions.send_notification_modal'))
                        ->visible(fn (User $record) => ! $record->is_admin)
                        ->schema([
                            TextInput::make('title_ar')
                                ->label(__('waffer.actions.notification_title').' (AR)')
                                ->required()
                                ->maxLength(255),
                            TextInput::make('title_en')
                                ->label(__('waffer.actions.notification_title').' (EN)')
                                ->required()
                                ->maxLength(255),
                            Textarea::make('message_ar')
                                ->label(__('waffer.actions.notification_message').' (AR)')
                                ->required()
                                ->rows(3),
                            Textarea::make('message_en')
                                ->label(__('waffer.actions.notification_message').' (EN)')
                                ->required()
                                ->rows(3),
                            Select::make('severity')
                                ->label(__('waffer.actions.notification_severity'))
                                ->required()
                                ->default('info')
                                ->options([
                                    'info' => __('waffer.enums.severity.info'),
                                    'warning' => __('waffer.enums.severity.warning'),
                                    'critical' => __('waffer.enums.severity.critical'),
                                    'success' => __('waffer.enums.severity.success'),
                                ]),
                        ])
                        ->action(function (User $record, array $data) {
                            Alert::create([
                                'user_id' => $record->id,
                                'type' => 'admin_message',
                                'severity' => $data['severity'],
                                'title_ar' => $data['title_ar'],
                                'title_en' => $data['title_en'],
                                'message_ar' => $data['message_ar'],
                                'message_en' => $data['message_en'],
                                'payload' => [
                                    'sent_by' => 'admin',
                                    'sent_at' => now()->toIso8601String(),
                                ],
                            ]);

                            $devices = $record->activeDeviceTokens()->count();

                            Notification::make()
                                ->title(__('waffer.actions.notification_sent'))
                                ->body(__('waffer.actions.notification_sent_to_devices', ['count' => $devices]))
                                ->success()
                                ->send();
                        }),

                    Action::make('sendPushOnly')
                        ->label(__('waffer.actions.send_push_only'))
                        ->icon('heroicon-o-paper-airplane')
                        ->color('primary')
                        ->modalHeading(__('waffer.actions.send_push_only_modal'))
                        ->visible(fn (User $record) => ! $record->is_admin && $record->activeDeviceTokens()->exists())
                        ->schema([
                            TextInput::make('title_ar')
                                ->label(__('waffer.actions.notification_title').' (AR)')
                                ->required()
                                ->maxLength(255),
                            TextInput::make('title_en')
                                ->label(__('waffer.actions.notification_title').' (EN)')
                                ->required()
                                ->maxLength(255),
                            Textarea::make('body_ar')
                                ->label(__('waffer.actions.notification_message').' (AR)')
                                ->required()
                                ->rows(3),
                            Textarea::make('body_en')
                                ->label(__('waffer.actions.notification_message').' (EN)')
                                ->required()
                                ->rows(3),
                            Select::make('severity')
                                ->label(__('waffer.actions.notification_severity'))
                                ->required()
                                ->default('info')
                                ->options([
                                    'info' => __('waffer.enums.severity.info'),
                                    'warning' => __('waffer.enums.severity.warning'),
                                    'critical' => __('waffer.enums.severity.critical'),
                                    'success' => __('waffer.enums.severity.success'),
                                ]),
                        ])
                        ->action(function (User $record, array $data, FcmService $fcm) {
                            $result = $fcm->sendToUser($record, [
                                'title_ar' => $data['title_ar'],
                                'title_en' => $data['title_en'],
                                'body_ar' => $data['body_ar'],
                                'body_en' => $data['body_en'],
                                'severity' => $data['severity'],
                                'data' => [
                                    'type' => 'admin_push',
                                    'sent_by' => 'admin',
                                ],
                            ]);

                            Notification::make()
                                ->title(__('waffer.actions.push_sent'))
                                ->body(__('waffer.actions.push_sent_stats', $result))
                                ->success()
                                ->send();
                        }),
                ])->iconButton(),
            ])
            ->headerActions([
                ExportAction::make()
                    ->label(__('waffer.actions.export'))
                    ->exporter(UserExporter::class),
            ])
            ->toolbarActions([
                BulkActionGroup::make([
                    ExportBulkAction::make()
                        ->label(__('waffer.actions.export'))
                        ->exporter(UserExporter::class),

                    BulkAction::make('broadcastPush')
                        ->label(__('waffer.actions.send_push_only'))
                        ->icon('heroicon-o-megaphone')
                        ->color('primary')
                        ->modalHeading(__('waffer.actions.send_push_only_modal'))
                        ->schema([
                            TextInput::make('title_ar')
                                ->label(__('waffer.actions.notification_title').' (AR)')
                                ->required()
                                ->maxLength(255),
                            TextInput::make('title_en')
                                ->label(__('waffer.actions.notification_title').' (EN)')
                                ->required()
                                ->maxLength(255),
                            Textarea::make('body_ar')
                                ->label(__('waffer.actions.notification_message').' (AR)')
                                ->required()
                                ->rows(3),
                            Textarea::make('body_en')
                                ->label(__('waffer.actions.notification_message').' (EN)')
                                ->required()
                                ->rows(3),
                            Select::make('severity')
                                ->label(__('waffer.actions.notification_severity'))
                                ->required()
                                ->default('info')
                                ->options([
                                    'info' => __('waffer.enums.severity.info'),
                                    'warning' => __('waffer.enums.severity.warning'),
                                    'critical' => __('waffer.enums.severity.critical'),
                                    'success' => __('waffer.enums.severity.success'),
                                ]),
                        ])
                        ->action(function (Collection $records, array $data, FcmService $fcm) {
                            $payload = [
                                'title_ar' => $data['title_ar'],
                                'title_en' => $data['title_en'],
                                'body_ar' => $data['body_ar'],
                                'body_en' => $data['body_en'],
                                'severity' => $data['severity'],
                                'data' => [
                                    'type' => 'broadcast',
                                    'sent_by' => 'admin',
                                ],
                            ];

                            $result = $fcm->sendToUsers($records->filter->is_active, $payload);

                            Notification::make()
                                ->title(__('waffer.actions.push_sent'))
                                ->body(__('waffer.actions.push_sent_stats', $result))
                                ->success()
                                ->send();
                        }),

                    DeleteBulkAction::make(),
                ]),
            ]);
    }
}
