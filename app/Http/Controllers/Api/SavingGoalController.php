<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\SavingGoal\StoreSavingGoalRequest;
use App\Http\Resources\SavingGoalResource;
use App\Models\SavingGoal;
use App\Models\Transaction;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

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

        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01'],
            'note' => ['nullable', 'string', 'max:500'],
            'transaction_date' => ['nullable', 'date'],
        ]);

        // A deposit IS a transaction. The TransactionObserver picks it up and
        // updates the goal's `current_amount` cache via SavingGoalLinker.
        DB::transaction(function () use ($savingGoal, $request, $data) {
            Transaction::create([
                'user_id' => $request->user()->id,
                'saving_goal_id' => $savingGoal->id,
                'type' => 'saving',
                'amount' => $data['amount'],
                'currency' => $savingGoal->currency ?? $request->user()->currency,
                'description' => $data['note'] ?? "إيداع في هدف: {$savingGoal->title}",
                'source' => 'manual',
                'transaction_date' => $data['transaction_date'] ?? now(),
            ]);
        });

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

    /**
     * GET /saving-goals/{id}/deposits
     * Lists every transaction that funds this goal (= type=saving + saving_goal_id).
     * Supports optional ?year=&month= and pagination.
     */
    public function deposits(Request $request, SavingGoal $savingGoal): JsonResponse
    {
        $this->authorizeGoal($request, $savingGoal);

        $query = Transaction::query()
            ->where('user_id', $request->user()->id)
            ->where('saving_goal_id', $savingGoal->id)
            ->where('type', 'saving');

        if ($request->filled('year')) {
            $query->whereYear('transaction_date', max(2000, min(2100, $request->integer('year'))));
        }
        if ($request->filled('month')) {
            $query->whereMonth('transaction_date', max(1, min(12, $request->integer('month'))));
        }

        $perPage = max(1, min(50, $request->integer('per_page', 20)));
        $deposits = $query->orderByDesc('transaction_date')->paginate($perPage);

        return $this->successResponse([
            'items' => \App\Http\Resources\TransactionResource::collection($deposits),
            'meta' => [
                'current_page' => $deposits->currentPage(),
                'last_page' => $deposits->lastPage(),
                'total' => $deposits->total(),
                'sum' => (float) $deposits->getCollection()->sum('amount'),
            ],
        ]);
    }

    /**
     * GET /saving-goals/{id}/monthly-progress
     * Returns one row per (year, month) with deposit total + expected pace.
     * Backs the "كم وفّرت لكل شهر؟" view (BR-03).
     */
    public function monthlyProgress(Request $request, SavingGoal $savingGoal): JsonResponse
    {
        $this->authorizeGoal($request, $savingGoal);

        $rows = Transaction::query()
            ->selectRaw('YEAR(transaction_date) as y, MONTH(transaction_date) as m, SUM(amount) as total, COUNT(*) as cnt')
            ->where('user_id', $request->user()->id)
            ->where('saving_goal_id', $savingGoal->id)
            ->where('type', 'saving')
            ->groupByRaw('YEAR(transaction_date), MONTH(transaction_date)')
            ->orderByRaw('y DESC, m DESC')
            ->get();

        // Expected per-month pace = (target − initial) / total months in plan.
        $monthlyTarget = $this->expectedMonthlyTarget($savingGoal);

        $items = $rows->map(function ($row) use ($monthlyTarget) {
            $deposited = (float) $row->total;
            $delta = $monthlyTarget !== null ? round($deposited - $monthlyTarget, 2) : null;

            return [
                'year' => (int) $row->y,
                'month' => (int) $row->m,
                'deposited' => round($deposited, 2),
                'transaction_count' => (int) $row->cnt,
                'expected' => $monthlyTarget,
                'delta' => $delta,
                'on_track' => $delta === null ? null : $delta >= 0,
            ];
        })->values();

        return $this->successResponse([
            'items' => $items,
            'meta' => [
                'monthly_target' => $monthlyTarget,
                'goal_id' => $savingGoal->id,
                'currency' => $savingGoal->currency ?? $request->user()->currency ?? 'SAR',
            ],
        ]);
    }

    protected function expectedMonthlyTarget(SavingGoal $goal): ?float
    {
        if (! $goal->start_date || ! $goal->deadline) {
            return null;
        }

        $start = $goal->start_date instanceof \Carbon\Carbon ? $goal->start_date : \Carbon\Carbon::parse($goal->start_date);
        $end = $goal->deadline instanceof \Carbon\Carbon ? $goal->deadline : \Carbon\Carbon::parse($goal->deadline);

        $months = max(1, $start->copy()->startOfMonth()->diffInMonths($end->copy()->startOfMonth()) + 1);

        return round((float) $goal->target_amount / $months, 2);
    }

    protected function authorizeGoal(Request $request, SavingGoal $savingGoal): void
    {
        abort_if($savingGoal->user_id !== $request->user()->id, 403, 'غير مصرح');
    }
}
