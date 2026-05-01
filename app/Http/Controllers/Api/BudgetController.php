<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Budget\StoreBudgetRequest;
use App\Http\Resources\BudgetResource;
use App\Models\Budget;
use App\Services\BudgetService;
use App\Services\PeriodResolver;
use App\Services\ResolvedPeriod;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BudgetController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected BudgetService $budgetService,
        protected PeriodResolver $periodResolver,
    ) {}

    public function index(Request $request): JsonResponse
    {
        $query = Budget::query()
            ->with(['categories.category'])
            ->where('user_id', $request->user()->id);

        if ($request->filled('month')) {
            $query->where('month', max(1, min(12, $request->integer('month'))));
        }
        if ($request->filled('year')) {
            $query->where('year', max(2000, min(2100, $request->integer('year'))));
        }
        if ($request->filled('status')) {
            $status = $request->input('status');
            if (in_array($status, ['draft', 'active', 'closed'], true)) {
                $query->where('status', $status);
            }
        }

        $budgets = $query
            ->orderByDesc('year')
            ->orderByDesc('month')
            ->paginate($request->integer('per_page', 12));

        return $this->successResponse([
            'items' => BudgetResource::collection($budgets),
            'meta' => [
                'current_page' => $budgets->currentPage(),
                'last_page' => $budgets->lastPage(),
                'total' => $budgets->total(),
            ],
        ]);
    }

    public function current(Request $request): JsonResponse
    {
        $period = $this->periodResolver->resolve($request->user(), $request);

        $budget = $this->budgetService->getCurrentBudget($request->user(), $period->month, $period->year);

        // PeriodResolver may have already pointed us to the latest active budget;
        // ensure we surface it directly when the resolved period was sourced from it.
        if (! $budget && $period->source === ResolvedPeriod::SOURCE_LATEST_BUDGET && $period->budgetId !== null) {
            $budget = Budget::with(['categories.category'])->find($period->budgetId);
        }

        if (! $budget) {
            return response()->json([
                'success' => true,
                'message' => $period->source === ResolvedPeriod::SOURCE_EXPLICIT
                    ? 'لا توجد ميزانية لهذا الشهر'
                    : 'لا توجد ميزانية نشطة',
                'data' => null,
                'meta' => [
                    'period' => $period->toArray(),
                ],
            ]);
        }

        return response()->json([
            'success' => true,
            'message' => '',
            'data' => (new BudgetResource($budget))->resolve(),
            'meta' => [
                'period' => $period->toArray(),
                'budget_month' => (int) $budget->month,
                'budget_year' => (int) $budget->year,
            ],
        ]);
    }

    public function show(Request $request, Budget $budget): JsonResponse
    {
        $this->authorizeBudget($request, $budget);

        return $this->successResponse(new BudgetResource($budget->load('categories.category')));
    }

    public function store(StoreBudgetRequest $request): JsonResponse
    {
        $budget = $this->budgetService->createOrUpdateBudget($request->user(), $request->validated());

        return $this->successResponse(
            new BudgetResource($budget),
            'تم إنشاء الميزانية بنجاح',
            201
        );
    }

    public function update(StoreBudgetRequest $request, Budget $budget): JsonResponse
    {
        $this->authorizeBudget($request, $budget);

        $data = $request->validated();
        $data['month'] = $budget->month;
        $data['year'] = $budget->year;
        unset($data['period_start']);

        $updated = $this->budgetService->createOrUpdateBudget($request->user(), $data);

        return $this->successResponse(new BudgetResource($updated), 'تم تحديث الميزانية');
    }

    public function destroy(Request $request, Budget $budget): JsonResponse
    {
        $this->authorizeBudget($request, $budget);

        $budget->delete();

        return $this->successResponse(null, 'تم حذف الميزانية');
    }

    protected function authorizeBudget(Request $request, Budget $budget): void
    {
        abort_if($budget->user_id !== $request->user()->id, 403, 'غير مصرح');
    }
}
