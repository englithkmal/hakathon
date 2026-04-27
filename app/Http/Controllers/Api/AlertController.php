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
        $alerts = Alert::query()
            ->where('user_id', $request->user()->id)
            ->when($request->boolean('unread_only'), fn ($q) => $q->where('is_read', false))
            ->orderByDesc('created_at')
            ->paginate($request->integer('per_page', 20));

        return $this->successResponse([
            'items' => AlertResource::collection($alerts),
            'meta' => [
                'current_page' => $alerts->currentPage(),
                'last_page' => $alerts->lastPage(),
                'total' => $alerts->total(),
                'unread_count' => Alert::where('user_id', $request->user()->id)->where('is_read', false)->count(),
            ],
        ]);
    }

    public function markAsRead(Request $request, Alert $alert): JsonResponse
    {
        abort_if($alert->user_id !== $request->user()->id, 403, 'غير مصرح');

        $alert->update([
            'is_read' => true,
            'read_at' => now(),
        ]);

        return $this->successResponse(new AlertResource($alert->fresh()), 'تم وضع علامة مقروء');
    }

    public function markAllAsRead(Request $request): JsonResponse
    {
        Alert::where('user_id', $request->user()->id)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
            ]);

        return $this->successResponse(null, 'تم وضع علامة مقروء على جميع التنبيهات');
    }

    public function destroy(Request $request, Alert $alert): JsonResponse
    {
        abort_if($alert->user_id !== $request->user()->id, 403, 'غير مصرح');

        $alert->delete();

        return $this->successResponse(null, 'تم حذف التنبيه');
    }
}
