<?php

namespace App\Services;

use App\Models\Alert;
use App\Models\BudgetCategory;
use App\Models\SavingGoal;
use App\Models\User;
use Filament\Notifications\Notification;

class AlertService
{
    /**
     * Snaps a user-defined threshold percentage (e.g. 75) to the nearest enum
     * value supported by the `alerts.type` column ({50, 80, 100}). The user's
     * own threshold still controls *when* an alert fires; this only governs how
     * the row is labeled in storage so it survives the column constraint.
     */
    protected function normalizeThresholdType(int $threshold): string
    {
        if ($threshold >= 100) {
            return 'threshold_100';
        }
        if ($threshold >= 65) {
            return 'threshold_80';
        }

        return 'threshold_50';
    }

    public function checkBudgetThresholds(BudgetCategory $budgetCategory): void
    {
        $budgetCategory->loadMissing(['budget.user', 'category']);

        $percentage = $budgetCategory->usage_percentage;
        $userId = $budgetCategory->budget->user_id;
        $categoryName = $budgetCategory->category->name_ar ?? 'تصنيف';
        $categoryNameEn = $budgetCategory->category->name_en ?? 'Category';

        $alertType = match (true) {
            $percentage >= 100 => 'exceeded',
            $percentage >= $budgetCategory->alert_threshold => $this->normalizeThresholdType((int) $budgetCategory->alert_threshold),
            $percentage >= 50 => 'threshold_50',
            default => null,
        };

        if (! $alertType) {
            return;
        }

        $alreadyExists = Alert::query()
            ->where('user_id', $userId)
            ->where('budget_category_id', $budgetCategory->id)
            ->where('type', $alertType)
            ->whereDate('created_at', now()->toDateString())
            ->exists();

        if ($alreadyExists) {
            return;
        }

        $config = $this->buildBudgetAlertConfig($alertType, $categoryName, $categoryNameEn, $percentage);

        $alert = Alert::create([
            'user_id' => $userId,
            'budget_category_id' => $budgetCategory->id,
            'type' => $alertType,
            'severity' => $config['severity'],
            'title_ar' => $config['title_ar'],
            'title_en' => $config['title_en'],
            'message_ar' => $config['message_ar'],
            'message_en' => $config['message_en'],
            'icon' => 'heroicon-o-exclamation-triangle',
            'deeplink' => '/budget/'.$budgetCategory->budget_id,
            'payload' => [
                'percentage' => round($percentage, 2),
                'spent' => (float) $budgetCategory->spent_amount,
                'allocated' => (float) $budgetCategory->allocated_amount,
                'category' => $categoryName,
            ],
        ]);

        if (in_array($config['severity'], ['warning', 'critical'], true)) {
            $this->notifyAdmins(
                title: $config['title_ar'],
                body: $config['message_ar'],
                severity: $config['severity']
            );
        }
    }

    protected function notifyAdmins(string $title, string $body, string $severity): void
    {
        $admins = User::where('is_admin', true)->where('is_active', true)->get();

        if ($admins->isEmpty()) {
            return;
        }

        $notification = Notification::make()
            ->title($title)
            ->body($body)
            ->icon('heroicon-o-bell-alert');

        match ($severity) {
            'critical' => $notification->danger(),
            'warning' => $notification->warning(),
            'success' => $notification->success(),
            default => $notification->info(),
        };

        $notification->sendToDatabase($admins);
    }

    public function checkSavingGoalProgress(SavingGoal $goal): void
    {
        $percentage = $goal->progress_percentage;

        if ($percentage >= 100 && $goal->status !== 'achieved') {
            $goal->update(['status' => 'achieved']);

            $this->createGoalAlert($goal, 'goal_achieved', 'success', [
                'title_ar' => 'مبروك! حققت هدفك',
                'title_en' => 'Congratulations! Goal Achieved',
                'message_ar' => 'لقد حققت هدف "'.$goal->title.'" بنجاح! استمر بالتقدم.',
                'message_en' => 'You achieved your goal "'.$goal->title.'"! Keep going.',
            ]);

            return;
        }

        $milestone = $this->goalMilestoneFromPercentage($percentage);
        if ($milestone !== null && $percentage < 100) {
            $alreadyExists = Alert::query()
                ->where('saving_goal_id', $goal->id)
                ->where('type', 'goal_progress')
                ->where('payload->milestone', $milestone)
                ->exists();

            if ($alreadyExists) {
                return;
            }

            $this->createGoalAlert($goal, 'goal_progress', 'info', [
                'title_ar' => 'أنت في الطريق الصحيح!',
                'title_en' => 'You are on track!',
                'message_ar' => "وصلت إلى {$milestone}% من هدف \"{$goal->title}\"، أكمل!",
                'message_en' => "You reached {$milestone}% of \"{$goal->title}\". Keep it up!",
            ], [
                'milestone' => $milestone,
            ]);
        }
    }

    protected function createGoalAlert(
        SavingGoal $goal,
        string $type,
        string $severity,
        array $messages,
        array $extraPayload = []
    ): void
    {
        Alert::create([
            'user_id' => $goal->user_id,
            'saving_goal_id' => $goal->id,
            'type' => $type,
            'severity' => $severity,
            'title_ar' => $messages['title_ar'],
            'title_en' => $messages['title_en'],
            'message_ar' => $messages['message_ar'],
            'message_en' => $messages['message_en'],
            'icon' => 'heroicon-o-trophy',
            'deeplink' => '/goals/'.$goal->id,
            'payload' => array_merge([
                'goal_id' => $goal->id,
                'percentage' => $goal->progress_percentage,
                'current' => (float) $goal->current_amount,
                'target' => (float) $goal->target_amount,
            ], $extraPayload),
        ]);
    }

    protected function goalMilestoneFromPercentage(float $percentage): ?int
    {
        return match (true) {
            $percentage >= 75 => 75,
            $percentage >= 50 => 50,
            default => null,
        };
    }

    protected function buildBudgetAlertConfig(string $type, string $categoryAr, string $categoryEn, float $percentage): array
    {
        return match ($type) {
            'exceeded' => [
                'severity' => 'critical',
                'title_ar' => 'تجاوزت ميزانية '.$categoryAr,
                'title_en' => 'Exceeded budget for '.$categoryEn,
                'message_ar' => "لقد تجاوزت الميزانية المخصصة لـ \"{$categoryAr}\" بنسبة ".round($percentage - 100, 0).'%',
                'message_en' => "You exceeded your \"{$categoryEn}\" budget by ".round($percentage - 100, 0).'%',
            ],
            'threshold_80', 'threshold_100' => [
                'severity' => 'warning',
                'title_ar' => 'اقتربت من حد ميزانية '.$categoryAr,
                'title_en' => 'Nearing budget limit for '.$categoryEn,
                'message_ar' => "استهلكت {$percentage}% من ميزانية \"{$categoryAr}\"",
                'message_en' => "You used {$percentage}% of your \"{$categoryEn}\" budget",
            ],
            default => [
                'severity' => 'info',
                'title_ar' => 'متابعة ميزانية '.$categoryAr,
                'title_en' => 'Budget update for '.$categoryEn,
                'message_ar' => "وصلت إلى {$percentage}% من ميزانية \"{$categoryAr}\"",
                'message_en' => "You reached {$percentage}% of \"{$categoryEn}\" budget",
            ],
        };
    }
}
