<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\TipResource;
use App\Models\Tip;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TipController extends Controller
{
    use ApiResponse;

    public function index(Request $request): JsonResponse
    {
        $tips = Tip::query()
            ->with('category')
            ->where('is_active', true)
            ->when(
                $request->filled('audience'),
                fn ($q) => $q->whereIn('audience', [$request->input('audience'), 'all'])
            )
            ->when(
                $request->filled('category_id'),
                fn ($q) => $q->where('category_id', $request->input('category_id'))
            )
            ->orderBy('sort_order')
            ->limit($request->integer('limit', 20))
            ->get();

        return $this->successResponse(TipResource::collection($tips));
    }

    public function show(Tip $tip): JsonResponse
    {
        return $this->successResponse(new TipResource($tip->load('category')));
    }
}
