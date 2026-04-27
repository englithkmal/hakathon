<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Transaction\StoreTransactionRequest;
use App\Http\Resources\TransactionResource;
use App\Models\Transaction;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class TransactionController extends Controller
{
    use ApiResponse;

    public function index(Request $request): JsonResponse
    {
        $query = Transaction::query()
            ->with('category')
            ->where('user_id', $request->user()->id);

        if ($request->filled('type')) {
            $query->where('type', $request->input('type'));
        }

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->input('category_id'));
        }

        if ($request->filled('from')) {
            $query->whereDate('transaction_date', '>=', $request->input('from'));
        }

        if ($request->filled('to')) {
            $query->whereDate('transaction_date', '<=', $request->input('to'));
        }

        if ($request->filled('search')) {
            $term = $request->input('search');
            $query->where(function ($q) use ($term) {
                $q->where('description', 'like', "%{$term}%")
                    ->orWhere('merchant', 'like', "%{$term}%");
            });
        }

        $transactions = $query
            ->orderByDesc('transaction_date')
            ->paginate($request->integer('per_page', 20));

        return $this->successResponse([
            'items' => TransactionResource::collection($transactions),
            'meta' => [
                'current_page' => $transactions->currentPage(),
                'last_page' => $transactions->lastPage(),
                'total' => $transactions->total(),
            ],
        ]);
    }

    public function show(Request $request, Transaction $transaction): JsonResponse
    {
        $this->authorizeTransaction($request, $transaction);

        return $this->successResponse(new TransactionResource($transaction->load('category')));
    }

    public function store(StoreTransactionRequest $request): JsonResponse
    {
        $data = $request->validated();
        $data['user_id'] = $request->user()->id;
        $data['currency'] = $data['currency'] ?? $request->user()->currency;
        $data['source'] = $data['source'] ?? 'manual';
        $data['transaction_date'] = $data['transaction_date'] ?? now();

        $transaction = Transaction::create($data);

        return $this->successResponse(
            new TransactionResource($transaction->load('category')),
            'تمت إضافة المعاملة',
            201
        );
    }

    public function update(StoreTransactionRequest $request, Transaction $transaction): JsonResponse
    {
        $this->authorizeTransaction($request, $transaction);

        $transaction->update($request->validated());

        return $this->successResponse(
            new TransactionResource($transaction->fresh('category')),
            'تم تحديث المعاملة'
        );
    }

    public function destroy(Request $request, Transaction $transaction): JsonResponse
    {
        $this->authorizeTransaction($request, $transaction);

        $transaction->delete();

        return $this->successResponse(null, 'تم حذف المعاملة');
    }

    protected function authorizeTransaction(Request $request, Transaction $transaction): void
    {
        abort_if($transaction->user_id !== $request->user()->id, 403, 'غير مصرح');
    }
}
