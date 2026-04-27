<?php

namespace Database\Seeders;

use App\Models\Tip;
use Illuminate\Database\Seeder;

class TipSeeder extends Seeder
{
    public function run(): void
    {
        $tips = [
            [
                'title_ar' => 'ابدأ ميزانيتك من اليوم الأول',
                'title_en' => 'Start your budget on day one',
                'content_ar' => 'حدّد سقفاً لكل تصنيف في بداية الشهر، فمن يضع خطة لا يفاجأ بنهاية الشهر.',
                'content_en' => 'Set a cap for each category at the start of the month — those who plan are never surprised at month-end.',
                'icon' => 'heroicon-o-clipboard-document-list',
                'audience' => 'all',
            ],
            [
                'title_ar' => 'قاعدة 50/30/20',
                'title_en' => 'The 50/30/20 rule',
                'content_ar' => '50% للضروريات، 30% للرغبات، 20% للادخار والاستثمار. قسمة بسيطة تحمي محفظتك.',
                'content_en' => '50% needs, 30% wants, 20% savings & investment. A simple split that protects your wallet.',
                'icon' => 'heroicon-o-calculator',
                'audience' => 'all',
            ],
            [
                'title_ar' => 'ادفع لنفسك أولاً',
                'title_en' => 'Pay yourself first',
                'content_ar' => 'أول ما يصلك راتبك، حوّل نسبة الادخار للحساب الادخاري قبل أي مصروف آخر.',
                'content_en' => 'The moment your salary arrives, transfer your savings target before any other expense.',
                'icon' => 'heroicon-o-banknotes',
                'audience' => 'all',
            ],
            [
                'title_ar' => 'سجّل كل معاملة فور حدوثها',
                'title_en' => 'Log every transaction immediately',
                'content_ar' => 'الذاكرة خادعة — التسجيل الفوري يمنحك صورة دقيقة عن أين يذهب مالك.',
                'content_en' => "Memory deceives — immediate logging gives you a true picture of where your money goes.",
                'icon' => 'heroicon-o-pencil-square',
                'audience' => 'all',
            ],
            [
                'title_ar' => 'ميّز بين الحاجة والرغبة',
                'title_en' => 'Distinguish needs from wants',
                'content_ar' => 'قبل كل عملية شراء، اسأل: هل أحتاجه فعلاً، أم أرغب فيه فقط؟',
                'content_en' => 'Before every purchase, ask: do I really need this, or do I just want it?',
                'icon' => 'heroicon-o-light-bulb',
                'audience' => 'all',
            ],
            [
                'title_ar' => 'صندوق طوارئ بـ 3 رواتب',
                'title_en' => 'A 3-salary emergency fund',
                'content_ar' => 'استهدف ادخار ما يعادل 3 رواتب لمواجهة الأحداث المفاجئة بدون قرض أو ضغط.',
                'content_en' => 'Aim to save the equivalent of 3 salaries to face surprises without loans or stress.',
                'icon' => 'heroicon-o-shield-check',
                'audience' => 'all',
            ],
            [
                'title_ar' => 'راجع اشتراكاتك الشهرية',
                'title_en' => 'Audit your monthly subscriptions',
                'content_ar' => 'الاشتراكات الصامتة تستنزف بهدوء. ألغِ ما لا تستخدمه، ووفّر ١٠٠٪ من تكلفته.',
                'content_en' => 'Silent subscriptions drain quietly. Cancel what you don’t use and save 100% of its cost.',
                'icon' => 'heroicon-o-arrow-path-rounded-square',
                'audience' => 'all',
            ],
            [
                'title_ar' => 'قاعدة الـ 24 ساعة',
                'title_en' => 'The 24-hour rule',
                'content_ar' => 'قبل أي شراء غير ضروري، انتظر 24 ساعة. غالباً ستجد أن الرغبة قد تلاشت.',
                'content_en' => 'Before any non-essential purchase, wait 24 hours. The urge often fades.',
                'icon' => 'heroicon-o-clock',
                'audience' => 'all',
            ],
            [
                'title_ar' => 'حدّد هدفاً ادخارياً واضحاً',
                'title_en' => 'Set a specific savings goal',
                'content_ar' => 'هدف غامض = نتيجة غامضة. اكتب الرقم والتاريخ، وابدأ في تتبّعه.',
                'content_en' => 'A vague goal = vague results. Write the number and the date, then track it.',
                'icon' => 'heroicon-o-flag',
                'audience' => 'all',
            ],
            [
                'title_ar' => 'تابع تقريرك الشهري',
                'title_en' => 'Review your monthly report',
                'content_ar' => 'مراجعة تقرير الشهر السابق هي أقصر طريق لتحسين أداء الشهر القادم.',
                'content_en' => 'Reviewing last month’s report is the shortest path to improving the next.',
                'icon' => 'heroicon-o-chart-bar',
                'audience' => 'all',
            ],
        ];

        foreach ($tips as $i => $row) {
            Tip::updateOrCreate(
                ['title_en' => $row['title_en']],
                array_merge($row, [
                    'is_active' => true,
                    'sort_order' => ($i + 1) * 10,
                ])
            );
        }

        $this->command?->info('Seeded '.count($tips).' financial tips.');
    }
}
