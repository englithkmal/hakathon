<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\AlertResource;
use App\Models\Alert;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AlertController extends Controller
{
    use ApiResponse;

    public function index(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'cursor' => ['nullable', 'integer', 'min:0'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'], // backward compatibility
            'unread_only' => ['nullable', 'boolean'],
            'type' => ['nullable', 'string', 'in:tip,goal_milestone,budget_alert,bank_sync,system,transaction'],
        ]);

        $limit = max(1, min(50, $request->integer('limit', $request->integer('per_page', 20))));
        $cursor = (int) ($validated['cursor'] ?? 0);
        $requestedType = $validated['type'] ?? null;

        $query = Alert::query()
            ->with([
                'savingGoal',
                'budgetCategory.category',
                'budgetCategory.budget',
            ])
            ->where('user_id', $request->user()->id)
            ->when($request->boolean('unread_only'), fn ($q) => $q->where('is_read', false))
            ->when($requestedType, fn ($q) => $q->whereIn('type', $this->rawTypesForFilter($requestedType)))
            ->when($cursor > 0, fn ($q) => $q->where('id', '<', $cursor))
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        $alerts = $query->limit($limit + 1)->get();
        $hasMore = $alerts->count() > $limit;
        $items = $alerts->take($limit)->values();
        $lastItem = $items->last();
        $nextCursor = $hasMore && $lastItem ? (int) $lastItem->id : null;
        $unreadCount = (int) Alert::query()
            ->where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return $this->successResponse([
            'items' => AlertResource::collection($items),
            'next_cursor' => $nextCursor,
            'unread_count' => $unreadCount,
        ]);
    }

    public function markAsRead(Request $request, Alert $alert): JsonResponse
    {
        abort_if($alert->user_id !== $request->user()->id, 403, 'غير مصرح');

        $alert->update([
            'is_read' => true,
            'read_at' => now(),
        ]);

        $fresh = $alert->fresh();

        return $this->successResponse([
            'id' => $fresh->id,
            'is_read' => (bool) $fresh->is_read,
            'read_at' => $fresh->read_at?->toIso8601String(),
        ], 'تم وضع علامة مقروء');
    }

    public function markAllAsRead(Request $request): JsonResponse
    {
        $markedCount = Alert::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
            ]);

        return $this->successResponse([
            'marked_count' => (int) $markedCount,
            'unread_count' => 0,
        ], 'تم وضع علامة مقروء على جميع التنبيهات');
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $count = Alert::query()
            ->where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->count();

        return $this->successResponse([
            'unread_count' => (int) $count,
        ]);
    }

    /**
     * @return list<string>
     */
    protected function rawTypesForFilter(string $type): array
    {
        return match ($type) {
            'tip' => ['tip'],
            'goal_milestone' => ['goal_progress', 'goal_achieved'],
            'goal_off_track' => ['goal_off_track'],
            'budget_alert' => ['threshold_50', 'threshold_80', 'threshold_100', 'exceeded', 'low_balance'],
            'monthly_summary' => ['monthly_summary_ready'],
            // Best effort with existing schema: system/admin_message may include sync messages.
            'bank_sync' => ['system', 'admin_message'],
            'system' => ['system', 'admin_message'],
            'transaction' => ['system'],
            default => ['system'],
        };
    }

    public function destroy(Request $request, Alert $alert): JsonResponse
    {
        abort_if($alert->user_id !== $request->user()->id, 403, 'غير مصرح');

        $alert->delete();

        return $this->successResponse(null, 'تم حذف التنبيه');
    }
}
