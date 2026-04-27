<?php

namespace App\Services;

use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class MockBankService
{
    protected string $dataPath;

    public function __construct()
    {
        $this->dataPath = database_path('data/mock_transactions.json');
    }

    public function importForUser(User $user, bool $clearExisting = false): array
    {
        if (! file_exists($this->dataPath)) {
            throw new \RuntimeException("Mock data file not found at: {$this->dataPath}");
        }

        $payload = json_decode(file_get_contents($this->dataPath), true);

        if (! is_array($payload) || empty($payload['transactions'])) {
            throw new \RuntimeException('Invalid mock data structure');
        }

        $categoriesBySlug = Category::whereNull('user_id')
            ->whereIn('slug', collect($payload['transactions'])->pluck('category_slug')->unique()->all())
            ->get()
            ->keyBy('slug');

        return DB::transaction(function () use ($user, $payload, $categoriesBySlug, $clearExisting) {
            if ($clearExisting) {
                Transaction::where('user_id', $user->id)
                    ->where('source', 'mock_bank')
                    ->delete();
            }

            $imported = [];

            foreach ($payload['transactions'] as $row) {
                $category = $categoriesBySlug->get($row['category_slug'] ?? null);

                $transaction = Transaction::create([
                    'user_id' => $user->id,
                    'category_id' => $category?->id,
                    'amount' => $row['amount'],
                    'currency' => $row['currency'] ?? $user->currency ?? 'SAR',
                    'type' => $row['type'],
                    'description' => $row['description'] ?? null,
                    'merchant' => $row['merchant'] ?? null,
                    'source' => 'mock_bank',
                    'reference' => 'MOCK-'.strtoupper(substr(md5(uniqid()), 0, 10)),
                    'transaction_date' => Carbon::now()
                        ->subDays((int) ($row['days_ago'] ?? 0))
                        ->setTime(rand(8, 22), rand(0, 59)),
                ]);

                $imported[] = $transaction;
            }

            return [
                'count' => count($imported),
                'transactions' => $imported,
            ];
        });
    }

    public function clearMockData(User $user): int
    {
        return Transaction::where('user_id', $user->id)
            ->where('source', 'mock_bank')
            ->delete();
    }
}
