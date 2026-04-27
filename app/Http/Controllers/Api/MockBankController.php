<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\TransactionResource;
use App\Services\MockBankService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MockBankController extends Controller
{
    use ApiResponse;

    public function __construct(protected MockBankService $service) {}

    public function import(Request $request): JsonResponse
    {
        $clear = $request->boolean('clear', false);

        $result = $this->service->importForUser($request->user(), $clear);

        return $this->successResponse([
            'count' => $result['count'],
            'transactions' => TransactionResource::collection(collect($result['transactions'])->take(10)),
        ], 'تم استيراد '.$result['count'].' معاملة تجريبية', 201);
    }

    public function clear(Request $request): JsonResponse
    {
        $deleted = $this->service->clearMockData($request->user());

        return $this->successResponse(
            ['deleted_count' => $deleted],
            'تم حذف '.$deleted.' معاملة تجريبية'
        );
    }
}
