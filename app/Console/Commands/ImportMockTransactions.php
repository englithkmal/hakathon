<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\MockBankService;
use Illuminate\Console\Command;

class ImportMockTransactions extends Command
{
    protected $signature = 'waffer:import-mock-transactions
                            {phone : رقم هاتف المستخدم}
                            {--clear : حذف معاملات Mock السابقة قبل الاستيراد}';

    protected $description = 'استيراد معاملات بنكية تجريبية لمستخدم محدد';

    public function handle(MockBankService $service): int
    {
        $phone = $this->argument('phone');
        $clear = (bool) $this->option('clear');

        $user = User::where('phone', $phone)->first();

        if (! $user) {
            $this->error("❌ المستخدم بالهاتف {$phone} غير موجود");

            return self::FAILURE;
        }

        $this->info("📥 استيراد المعاملات للمستخدم: {$user->name} ({$user->phone})");

        if ($clear) {
            $deleted = $service->clearMockData($user);
            $this->warn("🗑️  حُذفت {$deleted} معاملة Mock سابقة");
        }

        $result = $service->importForUser($user, false);

        $this->info("✅ تم استيراد {$result['count']} معاملة بنجاح");
        $this->newLine();
        $this->table(
            ['التاريخ', 'النوع', 'المبلغ', 'الجهة', 'الوصف'],
            collect($result['transactions'])->take(10)->map(fn ($t) => [
                $t->transaction_date->format('Y-m-d H:i'),
                $t->type,
                number_format($t->amount, 2).' '.$t->currency,
                $t->merchant,
                $t->description,
            ])->all()
        );

        return self::SUCCESS;
    }
}
