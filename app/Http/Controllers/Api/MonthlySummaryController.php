<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MonthlySummaryResource;
use App\Models\MonthlySummary;
use App\Models\SavingGoal;
use App\Models\Transaction;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Surfaces the immutable monthly snapshots and the only legitimate mutation
 * path: allocating a portion of `unallocated_savings` into a saving goal
 * (BR-07). The snapshot itself is built by `waffer:close-month` and never
 * mutated by a client request.
 */
class MonthlySummaryController extends Controller
{
    use ApiResponse;

    public function index(Request $request): JsonResponse
    {
        $perPage = max(1, min(50, $request->integer('per_page', 12)));

        $query = MonthlySummary::query()
            ->where('user_id', $request->user()->id);

        if ($request->filled('year')) {
            $query->where('year', max(2000, min(2100, $request->integer('year'))));
        }

        $summaries = $query
            ->orderByDesc('year')
            ->orderByDesc('month')
            ->paginate($perPage);

        return $this->successResponse([
            'items' => MonthlySummaryResource::collection($summaries),
            'meta' => [
                'current_page' => $summaries->currentPage(),
                'last_page' => $summaries->lastPage(),
                'total' => $summaries->total(),
            ],
        ]);
    }

    public function show(Request $request, int $year, int $month): JsonResponse
    {
        $year = max(2000, min(2100, $year));
        $month = max(1, min(12, $month));

        $summary = MonthlySummary::query()
            ->where('user_id', $request->user()->id)
            ->where('year', $year)
            ->where('month', $month)
            ->first();

        if (! $summary) {
            return response()->json([
                'success' => true,
                'message' => 'لا يوجد سجل إغلاق لهذا الشهر',
                'data' => null,
                'meta' => [
                    'year' => $year,
                    'month' => $month,
                ],
            ]);
        }

        return $this->successResponse(new MonthlySummaryResource($summary));
    }

    /**
     * POST /monthly-summaries/{id}/allocate
     * Transfers part of the user's "وفر الشهر" into a saving goal as a typed
     * deposit. The transaction itself becomes the canonical record (BR-04/07).
     */
    public function allocate(Request $request, MonthlySummary $monthlySummary): JsonResponse
    {
        abort_if($monthlySummary->user_id !== $request->user()->id, 403, 'غير مصرح');

        $data = $request->validate([
            'goal_id' => ['required', 'integer', 'exists:saving_goals,id'],
            'amount' => ['required', 'numeric', 'min:0.01'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $goal = SavingGoal::query()
            ->where('id', $data['goal_id'])
            ->where('user_id', $request->user()->id)
            ->first();

        if (! $goal) {
            return $this->errorResponse('الهدف غير موجود أو غير تابع لك', 404);
        }

        if (! in_array($goal->status, ['active', 'paused'], true)) {
            return $this->errorResponse('لا يمكن الإيداع في هدف بحالة '.$goal->status, 422);
        }

        $unallocatedRemaining = max(
            0,
            (float) $monthlySummary->unallocated_savings - (float) $monthlySummary->allocated_amount
        );

        if ((float) $data['amount'] > $unallocatedRemaining + 0.001) {
            return $this->errorResponse(
                "المبلغ المطلوب يتجاوز ما تبقى من وفر الشهر ({$unallocatedRemaining})",
                422
            );
        }

        $transaction = DB::transaction(function () use ($monthlySummary, $goal, $data, $request) {
            return Transaction::create([
                'user_id' => $request->user()->id,
                'saving_goal_id' => $goal->id,
                'monthly_summary_id' => $monthlySummary->id,
                'type' => 'saving',
                'amount' => $data['amount'],
                'currency' => $goal->currency ?? $request->user()->currency ?? 'SAR',
                'description' => $data['note'] ?? "تخصيص من وفر {$monthlySummary->year}/{$monthlySummary->month} إلى: {$goal->title}",
                'source' => 'manual',
                'transaction_date' => now(),
            ]);
        });

        // The TransactionObserver took care of:
        //   - SavingGoalLinker::recompute (goal.current_amount)
        //   - MonthlySummary allocation totals (via the observer hook added in this step)
        return $this->successResponse(
            [
                'transaction_id' => $transaction->id,
                'monthly_summary' => new MonthlySummaryResource($monthlySummary->fresh()),
                'saving_goal' => [
                    'id' => $goal->fresh()->id,
                    'title' => $goal->title,
                    'current_amount' => (float) $goal->fresh()->current_amount,
                    'target_amount' => (float) $goal->target_amount,
                    'status' => $goal->fresh()->status,
                ],
            ],
            'تم تخصيص المبلغ من وفر الشهر إلى الهدف',
            201
        );
    }
}
