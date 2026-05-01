<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class AlertResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $locale = app()->getLocale();

        $normalizedType = $this->normalizedType();
        $normalizedSeverity = $this->normalizedSeverity();
        $payload = $this->normalizedPayload();

        return [
            'id' => $this->id,
            'type' => $normalizedType,
            'severity' => $normalizedSeverity,
            'title' => $locale === 'ar' ? ($this->title_ar ?? '') : ($this->title_en ?? ''),
            'title_ar' => $this->title_ar ?? '',
            'title_en' => $this->title_en ?? '',
            'message' => $locale === 'ar' ? ($this->message_ar ?? '') : ($this->message_en ?? ''),
            'message_ar' => $this->message_ar ?? '',
            'message_en' => $this->message_en ?? '',
            'icon' => $this->icon ?? $this->iconForType($normalizedType),
            'is_read' => (bool) $this->is_read,
            'read_at' => $this->read_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
            'deeplink' => $this->deeplink ?? $this->deeplinkForType($normalizedType, $payload),
            'payload' => $payload,
        ];
    }

    protected function normalizedType(): string
    {
        $raw = (string) $this->type;

        return match ($raw) {
            'tip' => 'tip',
            'goal_progress', 'goal_achieved' => 'goal_milestone',
            'goal_off_track' => 'goal_off_track',
            'threshold_50', 'threshold_80', 'threshold_100', 'exceeded', 'low_balance' => 'budget_alert',
            'monthly_summary_ready' => 'monthly_summary',
            default => $this->looksLikeBankSync() ? 'bank_sync' : 'system',
        };
    }

    protected function normalizedSeverity(): string
    {
        return match ((string) $this->severity) {
            'critical' => 'error',
            'warning' => 'warning',
            'success' => 'success',
            default => 'info',
        };
    }

    protected function iconForType(string $type): string
    {
        return match ($type) {
            'tip' => 'heroicon-o-light-bulb',
            'goal_milestone' => 'heroicon-o-trophy',
            'goal_off_track' => 'heroicon-o-arrow-trending-down',
            'budget_alert' => 'heroicon-o-exclamation-triangle',
            'monthly_summary' => 'heroicon-o-document-chart-bar',
            'bank_sync' => 'heroicon-o-arrow-path',
            'transaction' => 'heroicon-o-credit-card',
            default => 'heroicon-o-information-circle',
        };
    }

    protected function deeplinkForType(string $type, array $payload): ?string
    {
        return match ($type) {
            'goal_milestone', 'goal_off_track' => isset($payload['goal_id']) ? '/goals/'.$payload['goal_id'] : null,
            'budget_alert' => isset($payload['budget_id']) ? '/budget/'.$payload['budget_id'] : null,
            'tip' => isset($payload['tip_id']) ? '/tips/'.$payload['tip_id'] : null,
            'transaction' => isset($payload['transaction_id']) ? '/transactions/'.$payload['transaction_id'] : null,
            'monthly_summary' => isset($payload['monthly_summary_id'])
                ? '/monthly-summaries/'.$payload['monthly_summary_id']
                : (isset($payload['year'], $payload['month'])
                    ? "/monthly-summaries/{$payload['year']}/{$payload['month']}"
                    : null),
            default => null,
        };
    }

    protected function normalizedPayload(): array
    {
        $payload = is_array($this->payload) ? $this->payload : [];

        if ($this->savingGoal) {
            $goal = $this->savingGoal;
            $payload['goal_id'] ??= $goal->id;
            $payload['goal_title'] ??= $goal->title;
            $payload['goal_title_ar'] ??= $goal->title;
            $payload['goal_title_en'] ??= $goal->title;
            $payload['goal_progress_percentage'] ??= $goal->progress_percentage;
            $payload['goal_current_amount'] ??= (float) $goal->current_amount;
            $payload['goal_target_amount'] ??= (float) $goal->target_amount;
            $payload['goal_currency'] ??= $goal->currency;
        }

        if ($this->budgetCategory) {
            $category = $this->budgetCategory->category;
            $budget = $this->budgetCategory->budget;

            if ($budget) {
                $payload['budget_id'] ??= $budget->id;
                $payload['budget_overrun_percentage'] ??= max(0, round($this->budgetCategory->usage_percentage - 100, 2));
            }

            if ($category) {
                $payload['budget_category_name_ar'] ??= $category->name_ar;
                $payload['budget_category_name_en'] ??= $category->name_en;
            }
        }

        return $payload;
    }

    protected function looksLikeBankSync(): bool
    {
        $haystack = mb_strtolower(
            trim((string) ($this->title_ar ?? '').' '.(string) ($this->title_en ?? '').' '.(string) ($this->message_ar ?? '').' '.(string) ($this->message_en ?? ''))
        );

        return str_contains($haystack, 'مزامنة')
            || str_contains($haystack, 'sync')
            || (($this->payload['source'] ?? null) === 'mock_bank');
    }
}
