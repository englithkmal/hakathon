<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\SavingGoal\StoreSavingGoalRequest;
use App\Http\Resources\SavingGoalResource;
use App\Models\SavingGoal;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SavingGoalController extends Controller
{
    use ApiResponse;

    public function index(Request $request): JsonResponse
    {
        $goals = SavingGoal::query()
            ->where('user_id', $request->user()->id)
            ->when($request->filled('status'), fn ($q) => $q->where('status', $request->input('status')))
            ->orderByDesc('created_at')
            ->get();

        return $this->successResponse(SavingGoalResource::collection($goals));
    }

    public function show(Request $request, SavingGoal $savingGoal): JsonResponse
    {
        $this->authorizeGoal($request, $savingGoal);

        return $this->successResponse(new SavingGoalResource($savingGoal));
    }

    public function store(StoreSavingGoalRequest $request): JsonResponse
    {
        $data = $request->validated();
        $data['user_id'] = $request->user()->id;
        $data['currency'] = $data['currency'] ?? $request->user()->currency;
        $data['start_date'] = $data['start_date'] ?? now()->toDateString();

        $goal = SavingGoal::create($data);

        return $this->successResponse(new SavingGoalResource($goal), 'تم إنشاء الهدف', 201);
    }

    public function update(StoreSavingGoalRequest $request, SavingGoal $savingGoal): JsonResponse
    {
        $this->authorizeGoal($request, $savingGoal);

        $savingGoal->update($request->validated());

        return $this->successResponse(new SavingGoalResource($savingGoal->fresh()), 'تم تحديث الهدف');
    }

    public function deposit(Request $request, SavingGoal $savingGoal): JsonResponse
    {
        $this->authorizeGoal($request, $savingGoal);

        $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
        ]);

        $savingGoal->update([
            'current_amount' => (float) $savingGoal->current_amount + (float) $request->input('amount'),
        ]);

        return $this->successResponse(
            new SavingGoalResource($savingGoal->fresh()),
            'تمت إضافة المبلغ إلى الهدف'
        );
    }

    public function destroy(Request $request, SavingGoal $savingGoal): JsonResponse
    {
        $this->authorizeGoal($request, $savingGoal);

        $savingGoal->delete();

        return $this->successResponse(null, 'تم حذف الهدف');
    }

    protected function authorizeGoal(Request $request, SavingGoal $savingGoal): void
    {
        abort_if($savingGoal->user_id !== $request->user()->id, 403, 'غير مصرح');
    }
}
