<?php

namespace Database\Seeders;

use App\Models\Alert;
use App\Models\Budget;
use App\Models\Category;
use App\Models\DeviceToken;
use App\Models\SavingGoal;
use App\Models\Transaction;
use App\Models\User;
use App\Services\BudgetService;
use Carbon\Carbon;
use Illuminate\Database\Seeder;

/**
 * يملأ جداول التطبيق لمستخدم **موجود مسبقاً** (لا ينشئ مستخدماً جديداً).
 * افتراضياً: الاسم بالضبط "Odai Test" وليس أدمن.
 *
 * يمسح بيانات ذلك المستخدم المالية/التنبيهات/الأهداف/الأجهزة فقط ثم يعيد البناء.
 *
 *     php artisan db:seed --class=DemoUserAppDataSeeder
 */
class DemoUserAppDataSeeder extends Seeder
{
    /** اسم المستخدم في جدول users (كما هو في القاعدة) */
    public const TARGET_USER_NAME = 'Odai Test';

    /** عملة المعاملات والميزانيات = عملة المستخدم في users (افتراضي SAR) */
    protected string $currency = 'SAR';

    public function run(): void
    {
        $user = User::query()
            ->where('is_admin', false)
            ->where(function ($q) {
                $q->where('name', self::TARGET_USER_NAME)
                    ->orWhereRaw('TRIM(name) = ?', [self::TARGET_USER_NAME]);
            })
            ->first();

        if (! $user) {
            $this->command?->warn('لم يُعثر على مستخدم باسم «'.self::TARGET_USER_NAME.'». تخطّي التعبئة.');

            return;
        }

        $this->clearUserAppData($user);

        $user->refresh();
        $this->currency = strtoupper((string) ($user->currency ?: 'SAR'));

        $user->update([
            'monthly_income' => $user->monthly_income > 0
                ? $user->monthly_income
                : $this->scaleFromSarBaseline(18500.0),
            'language' => $user->language ?: 'ar',
        ]);

        $user->refresh();

        $this->seedUserCategories($user);

        $defaults = Category::query()
            ->whereNull('user_id')
            ->where('is_active', true)
            ->pluck('id', 'slug')
            ->all();

        $cat = fn (string $slug) => (int) ($defaults[$slug] ?? 0);

        $budgetService = app(BudgetService::class);
        $now = now();

        for ($back = 5; $back >= 1; $back--) {
            $d = $now->copy()->subMonths($back);
            $month = (int) $d->month;
            $year = (int) $d->year;
            $factor = 0.75 + ($back * 0.04);

            $totalIncome = $this->scaleFromSarBaseline(round(17500 * $factor, 2));
            $alloc = [
                'housing' => $this->scaleFromSarBaseline(round(3200 * $factor, 2)),
                'food' => $this->scaleFromSarBaseline(round(1600 * $factor, 2)),
                'transport' => $this->scaleFromSarBaseline(round(950 * $factor, 2)),
                'bills' => $this->scaleFromSarBaseline(round(1300 * $factor, 2)),
                'entertainment' => $this->scaleFromSarBaseline(round(400 * $factor, 2)),
                'shopping' => $this->scaleFromSarBaseline(round(550 * $factor, 2)),
                'health' => $this->scaleFromSarBaseline(round(350 * $factor, 2)),
            ];
            $sumAlloc = array_sum($alloc);
            $spentScale = 0.55 + (($back % 3) * 0.1);

            $budget = $budgetService->createOrUpdateBudget($user, [
                'month' => $month,
                'year' => $year,
                'total_income' => $totalIncome,
                'total_amount' => $sumAlloc,
                'currency' => $this->currency,
                'status' => 'active',
                'notes' => 'ميزانية '.$d->locale('ar')->translatedFormat('F Y').' — إغلاق الشهر',
                'categories' => collect($alloc)
                    ->filter(fn ($amount, $slug) => $cat($slug) > 0)
                    ->map(fn ($amount, $slug) => [
                        'category_id' => $cat($slug),
                        'allocated_amount' => (float) $amount,
                        'alert_threshold' => 80,
                    ])
                    ->values()
                    ->all(),
            ]);

            $this->seedMonthTransactions(
                $user,
                $budget->id,
                $month,
                $year,
                $cat,
                $totalIncome,
                $alloc,
                $spentScale
            );

            $budgetService->recalculateSpent($budget->fresh());
            $budget->update(['status' => 'closed']);
        }

        $m = (int) $now->month;
        $y = (int) $now->year;

        $currentBudget = $budgetService->createOrUpdateBudget($user, [
            'month' => $m,
            'year' => $y,
            'total_income' => $this->scaleFromSarBaseline(18500),
            'total_amount' => $this->scaleFromSarBaseline(11200),
            'currency' => $this->currency,
            'status' => 'active',
            'notes' => 'ميزانية '.now()->locale('ar')->translatedFormat('F Y'),
            'categories' => [
                ['category_id' => $cat('housing'), 'allocated_amount' => $this->scaleFromSarBaseline(3600), 'alert_threshold' => 80],
                ['category_id' => $cat('food'), 'allocated_amount' => $this->scaleFromSarBaseline(1900), 'alert_threshold' => 80],
                ['category_id' => $cat('transport'), 'allocated_amount' => $this->scaleFromSarBaseline(1100), 'alert_threshold' => 80],
                ['category_id' => $cat('bills'), 'allocated_amount' => $this->scaleFromSarBaseline(1450), 'alert_threshold' => 75],
                ['category_id' => $cat('entertainment'), 'allocated_amount' => $this->scaleFromSarBaseline(550), 'alert_threshold' => 80],
                ['category_id' => $cat('shopping'), 'allocated_amount' => $this->scaleFromSarBaseline(650), 'alert_threshold' => 80],
                ['category_id' => $cat('health'), 'allocated_amount' => $this->scaleFromSarBaseline(450), 'alert_threshold' => 80],
                ['category_id' => $cat('education'), 'allocated_amount' => $this->scaleFromSarBaseline(350), 'alert_threshold' => 80],
                ['category_id' => $cat('other'), 'allocated_amount' => $this->scaleFromSarBaseline(550), 'alert_threshold' => 80],
            ],
        ]);

        $monthLabel = Carbon::create($y, $m, 1)->locale('ar')->translatedFormat('F Y');
        $this->seedCurrentMonthStory($user, $currentBudget->id, $m, $y, $cat, $user->id, $monthLabel);
        $budgetService->recalculateSpent($currentBudget->fresh());

        $this->seedSavingGoals($user);
        $this->seedAlerts($user, $currentBudget->fresh());
        $this->seedDevice($user);

        $this->command?->info('تم تعبئة بيانات التطبيق للمستخدم #'.$user->id.' ('.$user->name.').');
    }

    /**
     * الأرقام في الـ seeder مبنية على مبالغ معقولة بالريال؛ عند عملة أخرى تُحوَّل بنفس النسبة تقريباً.
     */
    protected function scaleFromSarBaseline(float $sarAmount): float
    {
        return match ($this->currency) {
            'USD' => round($sarAmount / 3.75, 2),
            'AED' => round($sarAmount / 1.02, 2),
            'EUR' => round($sarAmount / 4.1, 2),
            default => round($sarAmount, 2),
        };
    }

    protected function clearUserAppData(User $user): void
    {
        $user->tokens()->delete();
        DeviceToken::query()->where('user_id', $user->id)->delete();
        Alert::query()->where('user_id', $user->id)->delete();
        Transaction::query()->where('user_id', $user->id)->delete();
        Budget::query()->where('user_id', $user->id)->delete();
        SavingGoal::query()->where('user_id', $user->id)->delete();
        Category::query()->where('user_id', $user->id)->delete();
    }

    protected function seedUserCategories(User $user): void
    {
        Category::query()->create([
            'user_id' => $user->id,
            'name_ar' => 'عمل حر — تصميم',
            'name_en' => 'Freelance — Design',
            'slug' => 'freelance-design-'.$user->id,
            'icon' => 'heroicon-o-paint-brush',
            'color' => '#0D9488',
            'type' => 'income',
            'is_default' => false,
            'is_active' => true,
            'sort_order' => 50,
        ]);
    }

    /**
     * @param  array<string, int>  $alloc
     */
    protected function seedMonthTransactions(
        User $user,
        int $budgetId,
        int $month,
        int $year,
        callable $cat,
        float $totalIncome,
        array $alloc,
        float $spentScale
    ): void {
        $rows = [];

        $add = function (
            int $day,
            string $type,
            int $categoryId,
            float $amount,
            string $description,
            ?string $merchant,
            string $source = 'manual'
        ) use (&$rows, $user, $budgetId, $month, $year) {
            if ($categoryId <= 0 && $type === 'expense') {
                return;
            }
            $rows[] = [
                'user_id' => $user->id,
                'category_id' => $categoryId > 0 ? $categoryId : null,
                'budget_id' => $budgetId,
                'amount' => $amount,
                'currency' => $this->currency,
                'type' => $type,
                'description' => $description,
                'merchant' => $merchant,
                'source' => $source,
                'reference' => 'TXN-'.$year.sprintf('%02d', $month).'-'.str_pad((string) count($rows), 4, '0', STR_PAD_LEFT),
                'transaction_date' => Carbon::create($year, $month, min($day, 28), 10, 0, 0, config('app.timezone')),
                'created_at' => now(),
                'updated_at' => now(),
            ];
        };

        $add(1, 'income', $cat('salary'), $totalIncome, 'راتب شهري', 'شركة الرياض للتقنية', 'mock_bank');

        $day = 2;
        foreach ($alloc as $slug => $allocated) {
            if ($slug === 'housing') {
                $add($day, 'expense', $cat('housing'), round($allocated * $spentScale * 0.92), 'إيجار سكن', 'مالك العقار', 'mock_bank');
            }
            if ($slug === 'food') {
                $add($day + 1, 'expense', $cat('food'), round($allocated * $spentScale * 0.35), 'بقالة أسبوعية', 'كارفور', 'manual');
                $add($day + 2, 'expense', $cat('food'), round($allocated * $spentScale * 0.22), 'مطاعم', 'شاورمر', 'manual');
            }
            if ($slug === 'transport') {
                $add($day + 3, 'expense', $cat('transport'), round($allocated * $spentScale * 0.4), 'وقود', 'أرامكو', 'manual');
                $add($day + 4, 'expense', $cat('transport'), round($allocated * $spentScale * 0.25), 'أوبر', 'Uber', 'imported');
            }
            if ($slug === 'bills') {
                $add($day + 5, 'expense', $cat('bills'), round($allocated * $spentScale * 0.45), 'فاتورة كهرباء', 'سكاكا', 'mock_bank');
                $add($day + 6, 'expense', $cat('bills'), round($allocated * $spentScale * 0.3), 'جوال — stc', 'stc', 'mock_bank');
            }
            if ($slug === 'entertainment') {
                $add($day + 7, 'expense', $cat('entertainment'), round($allocated * $spentScale * 0.5), 'اشتراك منصة', 'Netflix', 'manual');
            }
            if ($slug === 'shopping') {
                $add($day + 8, 'expense', $cat('shopping'), round($allocated * $spentScale * 0.55), 'ملابس', 'نمشي', 'manual');
            }
            if ($slug === 'health') {
                $add($day + 9, 'expense', $cat('health'), round($allocated * $spentScale * 0.3), 'صيدلية', 'النهدي', 'manual');
            }
            $day += 2;
        }

        $add(25, 'saving', $cat('savings'), round($this->scaleFromSarBaseline(800 * $spentScale), 2), 'تحويل لحساب الادخار', 'تحويل داخلي', 'manual');
        if ($cat('extra-income') > 0) {
            $add(18, 'income', $cat('extra-income'), round($this->scaleFromSarBaseline(400 * $spentScale), 2), 'مكافأة أداء', 'الشركة', 'manual');
        }

        Transaction::withoutEvents(fn () => Transaction::query()->insert($rows));
    }

    protected function seedCurrentMonthStory(
        User $user,
        int $budgetId,
        int $month,
        int $year,
        callable $cat,
        int $userId,
        string $monthLabelAr
    ): void {
        $freelanceCat = Category::query()
            ->where('user_id', $userId)
            ->where('slug', 'like', 'freelance-design-%')
            ->value('id') ?? 0;

        $scenarios = [
            [1, 'income', $cat('salary'), 18500, 'راتب — '.$monthLabelAr, 'شركة نماء الرقمية', 'mock_bank'],
            [3, 'income', $freelanceCat, 1200, 'مشروع واجهة تطبيق', 'عميل — م. سالم', 'manual'],
            [2, 'expense', $cat('housing'), 3600, 'إيجار سكن — '.$monthLabelAr, 'عقد إلكتروني', 'mock_bank'],
            [4, 'expense', $cat('food'), 186, 'بقالة', 'بنده', 'manual'],
            [4, 'expense', $cat('food'), 64, 'قهوة', 'ستاربكس', 'manual'],
            [5, 'expense', $cat('transport'), 240, 'بنزين', 'محطة الدريس', 'manual'],
            [6, 'expense', $cat('bills'), 399, 'فاتورة الإنترنت', 'STC Fiber', 'mock_bank'],
            [7, 'expense', $cat('bills'), 289, 'مياه', 'شركة مياه', 'mock_bank'],
            [8, 'expense', $cat('food'), 142, 'غداء عمل', 'الباتشي', 'manual'],
            [9, 'expense', $cat('shopping'), 219, 'إكسسوارات لابتوب', 'جرير', 'manual'],
            [10, 'expense', $cat('health'), 89, 'فيتامينات', 'النهدي', 'manual'],
            [11, 'expense', $cat('entertainment'), 75, 'سينما', 'فوكس سينما', 'manual'],
            [12, 'expense', $cat('transport'), 34, 'أوبر', 'Uber', 'imported'],
            [13, 'expense', $cat('food'), 52, 'فطور', 'ماكدونالدز', 'manual'],
            [14, 'expense', $cat('bills'), 450, 'كهرباء — الجزء الأول', 'سكاكا', 'mock_bank'],
            [15, 'expense', $cat('food'), 178, 'عشاء عائلي', 'الرومانسية', 'manual'],
            [16, 'expense', $cat('shopping'), 310, 'هدايا عيد', 'سوق التطبيقات', 'manual'],
            [17, 'expense', $cat('education'), 199, 'دورة عبر الإنترنت', 'Udemy', 'manual'],
            [19, 'expense', $cat('other'), 120, 'صيانة سريعة', 'ورشة الحي', 'manual'],
            [20, 'expense', $cat('transport'), 180, 'بنزين', 'أرامكو', 'manual'],
            [21, 'expense', $cat('food'), 95, 'سوبرماركت صغير', 'التميمي', 'manual'],
            [22, 'expense', $cat('entertainment'), 45, 'اشتراك موسيقى', 'Spotify', 'manual'],
            [23, 'expense', $cat('bills'), 120, 'اشتراك تخزين سحابي', 'Google One', 'manual'],
            [24, 'expense', $cat('health'), 250, 'كشف طبي', 'مجمع طبي', 'manual'],
            [25, 'saving', $cat('savings'), 900, 'تحويل لرحلة العمرة', 'حساب ادخار', 'manual'],
            [26, 'expense', $cat('food'), 88, 'غداء', 'شاورمر', 'manual'],
            [27, 'expense', $cat('shopping'), 165, 'ملابس رياضية', 'نمشي', 'manual'],
            [28, 'expense', $cat('transport'), 55, 'مواقف وطرق', 'مواقف الرياض', 'manual'],
        ];

        $rows = [];
        foreach ($scenarios as $i => $row) {
            [$day, $type, $categoryId, $amount, $description, $merchant, $source] = $row;
            $amount = $this->scaleFromSarBaseline((float) $amount);
            if ($type === 'expense' && (int) $categoryId <= 0) {
                continue;
            }
            if ($type === 'income' && (int) $categoryId <= 0) {
                continue;
            }
            $rows[] = [
                'user_id' => $user->id,
                'category_id' => $categoryId > 0 ? $categoryId : null,
                'budget_id' => $budgetId,
                'amount' => $amount,
                'currency' => $this->currency,
                'type' => $type,
                'description' => $description,
                'merchant' => $merchant,
                'source' => $source,
                'reference' => 'TXN-CUR-'.str_pad((string) $i, 4, '0', STR_PAD_LEFT),
                'transaction_date' => Carbon::create($year, $month, min((int) $day, 28), 12, 0, 0, config('app.timezone')),
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        Transaction::withoutEvents(fn () => Transaction::query()->insert($rows));
    }

    protected function seedSavingGoals(User $user): void
    {
        SavingGoal::query()->insert([
            [
                'user_id' => $user->id,
                'title' => 'رحلة عمرة ٢٠٢٦',
                'description' => 'تكاليف السفر والإقامة للعائلة',
                'icon' => 'heroicon-o-globe-alt',
                'color' => '#059669',
                'target_amount' => $this->scaleFromSarBaseline(18000),
                'current_amount' => $this->scaleFromSarBaseline(11250),
                'currency' => $this->currency,
                'start_date' => now()->subMonths(4)->toDateString(),
                'deadline' => now()->addMonths(5)->toDateString(),
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'user_id' => $user->id,
                'title' => 'مقدم سيارة',
                'description' => 'دفعة أولى لسيارة عائلية',
                'icon' => 'heroicon-o-truck',
                'color' => '#2563EB',
                'target_amount' => $this->scaleFromSarBaseline(45000),
                'current_amount' => $this->scaleFromSarBaseline(12800),
                'currency' => $this->currency,
                'start_date' => now()->subMonths(8)->toDateString(),
                'deadline' => now()->addYear()->toDateString(),
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'user_id' => $user->id,
                'title' => 'صندوق طوارئ',
                'description' => '٦ أشهر من المصاريف الأساسية',
                'icon' => 'heroicon-o-shield-check',
                'color' => '#7C3AED',
                'target_amount' => $this->scaleFromSarBaseline(25000),
                'current_amount' => $this->scaleFromSarBaseline(19800),
                'currency' => $this->currency,
                'start_date' => now()->subYear()->toDateString(),
                'deadline' => now()->addMonths(10)->toDateString(),
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'user_id' => $user->id,
                'title' => 'لابتوب جديد',
                'description' => 'جهاز للعمل عن بُعد',
                'icon' => 'heroicon-o-computer-desktop',
                'color' => '#EA580C',
                'target_amount' => $this->scaleFromSarBaseline(5500),
                'current_amount' => $this->scaleFromSarBaseline(5500),
                'currency' => $this->currency,
                'start_date' => now()->subMonths(6)->toDateString(),
                'deadline' => now()->subMonth()->toDateString(),
                'status' => 'achieved',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);
    }

    protected function seedAlerts(User $user, Budget $currentBudget): void
    {
        $housingBc = $currentBudget->categories()->whereHas('category', fn ($q) => $q->where('slug', 'housing'))->first();
        $billsBc = $currentBudget->categories()->whereHas('category', fn ($q) => $q->where('slug', 'bills'))->first();
        $goal = SavingGoal::query()->where('user_id', $user->id)->where('title', 'رحلة عمرة ٢٠٢٦')->first();

        $base = now()->subDays(2);

        $alerts = [
            [
                'user_id' => $user->id,
                'budget_category_id' => $billsBc?->id,
                'saving_goal_id' => null,
                'type' => 'threshold_80',
                'severity' => 'warning',
                'title_ar' => 'اقتربت من حد ميزانية الفواتير',
                'title_en' => 'Nearing bills budget limit',
                'message_ar' => 'اقتربت من استنفاد مخصص الفواتير لهذا الشهر — راجع اشتراك الإنترنت والكهرباء.',
                'message_en' => 'You used over 80% of your bills budget this month.',
                'payload' => ['category' => 'فواتير', 'suggestion' => 'مراجعة الاشتراكات الثابتة'],
                'is_read' => false,
                'read_at' => null,
                'created_at' => $base,
                'updated_at' => $base,
            ],
            [
                'user_id' => $user->id,
                'budget_category_id' => $housingBc?->id,
                'saving_goal_id' => null,
                'type' => 'threshold_50',
                'severity' => 'info',
                'title_ar' => 'متابعة ميزانية السكن',
                'title_en' => 'Housing budget update',
                'message_ar' => 'تم خصم قيمة الإيجار — أنت ضمن المسار الطبيعي.',
                'message_en' => 'Rent posted — you are on a normal track.',
                'payload' => [],
                'is_read' => true,
                'read_at' => $base->copy()->addHour(),
                'created_at' => $base->copy()->subDay(),
                'updated_at' => $base->copy()->subDay(),
            ],
            [
                'user_id' => $user->id,
                'budget_category_id' => null,
                'saving_goal_id' => $goal?->id,
                'type' => 'goal_progress',
                'severity' => 'info',
                'title_ar' => 'أنت في الطريق الصحيح!',
                'title_en' => 'You are on track!',
                'message_ar' => 'تقدم جيد نحو هدف رحلة العمرة.',
                'message_en' => 'Good progress toward your Umrah goal.',
                'payload' => ['goal' => 'رحلة عمرة ٢٠٢٦'],
                'is_read' => false,
                'read_at' => null,
                'created_at' => $base->copy()->subHours(3),
                'updated_at' => $base->copy()->subHours(3),
            ],
            [
                'user_id' => $user->id,
                'budget_category_id' => null,
                'saving_goal_id' => null,
                'type' => 'tip',
                'severity' => 'info',
                'title_ar' => 'نصيحة اليوم',
                'title_en' => 'Tip of the day',
                'message_ar' => 'خصص ١٠٪ من دخلك لادخار تلقائي في أول الشهر.',
                'message_en' => 'Automate 10% savings on payday.',
                'payload' => [],
                'is_read' => true,
                'read_at' => $base->copy()->subDays(3),
                'created_at' => $base->copy()->subDays(3),
                'updated_at' => $base->copy()->subDays(3),
            ],
            [
                'user_id' => $user->id,
                'budget_category_id' => null,
                'saving_goal_id' => null,
                'type' => 'system',
                'severity' => 'info',
                'title_ar' => 'ملخص أسبوع الإنفاق',
                'title_en' => 'Weekly spending summary',
                'message_ar' => 'أعلى فئة إنفاق لديك هذا الأسبوع كانت الطعام؛ تخطيط وجبات العمل مسبقاً يساعد على ضبط المصروف دون تضييق كبير.',
                'message_en' => 'Your top spending category this week was food; planning work meals ahead helps steady spending.',
                'payload' => ['period' => '7_days', 'top_category' => 'food'],
                'is_read' => false,
                'read_at' => null,
                'created_at' => now()->subMinutes(30),
                'updated_at' => now()->subMinutes(30),
            ],
            [
                'user_id' => $user->id,
                'budget_category_id' => null,
                'saving_goal_id' => null,
                'type' => 'admin_message',
                'severity' => 'success',
                'title_ar' => 'تذكير — عرض اشتراك سنوي',
                'title_en' => 'Reminder — annual plan offer',
                'message_ar' => 'اشتراكك السنوي قابل للتجديد خلال أيام؛ يمكنك الاستفادة من السعر الحالي قبل أي تعديل لاحق.',
                'message_en' => 'Your annual plan can renew soon; you may lock in the current price before any change.',
                'payload' => ['renewal_window_days' => 14],
                'is_read' => false,
                'read_at' => null,
                'created_at' => now()->subHour(),
                'updated_at' => now()->subHour(),
            ],
        ];

        foreach ($alerts as $row) {
            Alert::query()->create($row);
        }
    }

    protected function seedDevice(User $user): void
    {
        DeviceToken::query()->create([
            'user_id' => $user->id,
            'token' => 'demo-fcm-user-'.$user->id.'-'.hash('sha256', (string) $user->id),
            'platform' => 'android',
            'device_name' => 'Pixel 8',
            'device_model' => 'Pixel 8',
            'app_version' => '1.0.0',
            'locale' => 'ar',
            'is_active' => true,
            'last_used_at' => now()->subMinutes(5),
        ]);
    }
}
