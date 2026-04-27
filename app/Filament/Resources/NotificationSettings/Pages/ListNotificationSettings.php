<?php

namespace App\Filament\Resources\NotificationSettings\Pages;

use App\Filament\Resources\NotificationSettings\NotificationSettingResource;
use Filament\Resources\Pages\ListRecords;

class ListNotificationSettings extends ListRecords
{
    protected static string $resource = NotificationSettingResource::class;

    public function getTitle(): string
    {
        return 'إعدادات الإشعارات';
    }

    public function getSubheading(): ?string
    {
        return 'تحكّم بالإشعارات التلقائية: تفعيل / تعطيل، تغيير الوقت، أو إرسال فوري لكل المستخدمين.';
    }
}
