<?php

namespace Database\Seeders;

use App\Models\NotificationSetting;
use Illuminate\Database\Seeder;

class NotificationSettingSeeder extends Seeder
{
    public function run(): void
    {
        $rows = [
            [
                'key' => 'daily_tip',
                'label_ar' => 'نصيحة اليوم',
                'label_en' => 'Daily Tip',
                'description_ar' => 'نصيحة مالية عشوائية تُرسَل لكل المستخدمين النشطين.',
                'description_en' => 'A random financial tip pushed to every active user.',
                'command' => 'waffer:daily-tip',
                'schedule_time' => '09:00',
                'schedule_frequency' => 'daily',
                'extra_config' => null,
            ],
            [
                'key' => 'monthly_report',
                'label_ar' => 'التقرير الشهري',
                'label_en' => 'Monthly Report',
                'description_ar' => 'ملخّص الشهر المنصرم: الدخل، المصروف، التوفير.',
                'description_en' => 'Summary of the previous month: income, expenses, savings.',
                'command' => 'waffer:monthly-report',
                'schedule_time' => '08:00',
                'schedule_frequency' => 'monthly',
                'schedule_day_of_month' => 1,
                'extra_config' => null,
            ],
            [
                'key' => 'goal_deadline_7d',
                'label_ar' => 'تذكير الهدف (قبل أسبوع)',
                'label_en' => 'Goal Deadline (7 days)',
                'description_ar' => 'تنبيه قبل 7 أيام من تاريخ نهاية أي هدف ادخار.',
                'description_en' => 'Alert 7 days before any saving goal deadline.',
                'command' => 'waffer:goal-deadline-reminders',
                'schedule_time' => '10:00',
                'schedule_frequency' => 'daily',
                'extra_config' => ['days' => 7],
            ],
            [
                'key' => 'goal_deadline_1d',
                'label_ar' => 'تذكير الهدف (يوم واحد)',
                'label_en' => 'Goal Deadline (1 day)',
                'description_ar' => 'آخر تذكير قبل يوم من تاريخ نهاية الهدف.',
                'description_en' => 'Last call — 1 day before goal deadline.',
                'command' => 'waffer:goal-deadline-reminders',
                'schedule_time' => '10:15',
                'schedule_frequency' => 'daily',
                'extra_config' => ['days' => 1],
            ],
            [
                'key' => 'budget_month_end',
                'label_ar' => 'نهاية الشهر — حالة الميزانية',
                'label_en' => 'Budget Month-End',
                'description_ar' => 'تذكير بحالة الميزانية في آخر 3 أيام من الشهر.',
                'description_en' => 'Budget status nudge during the last 3 days of the month.',
                'command' => 'waffer:budget-month-end',
                'schedule_time' => '19:00',
                'schedule_frequency' => 'daily',
                'extra_config' => null,
            ],
            [
                'key' => 'inactivity_reminder',
                'label_ar' => 'تذكير الخمول',
                'label_en' => 'Inactivity Reminder',
                'description_ar' => 'إعادة جذب المستخدمين الذين لم يسجلوا أي معاملة منذ 5 أيام أو أكثر.',
                'description_en' => 'Re-engage users with 5+ days of zero activity.',
                'command' => 'waffer:inactivity-reminder',
                'schedule_time' => '18:00',
                'schedule_frequency' => 'daily',
                'extra_config' => ['days' => 5],
            ],
        ];

        foreach ($rows as $row) {
            NotificationSetting::updateOrCreate(
                ['key' => $row['key']],
                array_merge($row, [
                    'is_enabled' => true,
                ])
            );
        }

        $this->command?->info('Seeded '.count($rows).' notification settings.');
    }
}
