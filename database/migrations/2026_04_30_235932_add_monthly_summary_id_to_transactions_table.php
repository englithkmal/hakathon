<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tags a transaction as "this is an allocation that originated from the
 * unallocated savings of a closed month" (BR-07). Used by:
 *   POST /monthly-summaries/{id}/allocate  — moves part of وفر الشهر into a goal.
 *
 * The allocation transaction itself looks like a normal saving deposit
 * (type=saving + saving_goal_id), but the FK lets us:
 *   - compute monthly_summaries.allocated_amount as a clean SUM of children;
 *   - audit-trail "where did this saving come from?".
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->foreignId('monthly_summary_id')
                ->nullable()
                ->after('saving_goal_id')
                ->constrained()
                ->nullOnDelete();

            $table->index('monthly_summary_id', 'transactions_monthly_summary_idx');
        });
    }

    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropIndex('transactions_monthly_summary_idx');
            $table->dropConstrainedForeignId('monthly_summary_id');
        });
    }
};
