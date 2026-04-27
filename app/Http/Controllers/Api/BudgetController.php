<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Budget\StoreBudgetRequest;
use App\Http\Resources\BudgetResource;
use App\Models\Budget;
use App\Services\BudgetService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BudgetController extends Controller
{
    use ApiResponse;

    public function __construct(protected BudgetService $budgetService) {}

    public function index(Request $request): JsonResponse
    {
        $budgets = Budget::query()
            ->with(['categories.category'])
            ->where('user_id', $request->user()->id)
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
        $budget = $this->budgetService->getCurrentBudget($request->user());

        if (! $budget) {
            return $this->successResponse(null, 'لا توجد ميزانية لهذا الشهر');
        }

        return $this->successResponse(new BudgetResource($budget));
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
