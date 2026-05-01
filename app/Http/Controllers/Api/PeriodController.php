<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\PeriodResolver;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Returns the period the rest of the API will use for this user, given the same
 * input contract (`?month=&year=` or `?period_start=`). Mobile clients can call
 * this once on cold-start to know which calendar period to highlight in the UI
 * before requesting Dashboard / Budgets / Insights.
 */
class PeriodController extends Controller
{
    use ApiResponse;

    public function __construct(protected PeriodResolver $periodResolver) {}

    public function show(Request $request): JsonResponse
    {
        $period = $this->periodResolver->resolve($request->user(), $request);

        return $this->successResponse([
            'period' => $period->toArray(),
        ]);
    }
}
