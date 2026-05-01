<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds the helper link from a transaction to a saving goal. The triple
 * (user_id, type=saving, saving_goal_id) becomes the source of truth for
 * "what was deposited into this goal"; saving_goals.current_amount becomes
 * a denormalized cache (same pattern as transactions↔budgets).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->foreignId('saving_goal_id')
                ->nullable()
                ->after('budget_id')
                ->constrained()
                ->nullOnDelete();

            $table->index(['user_id', 'saving_goal_id'], 'transactions_user_goal_idx');
        });
    }

    public function down(): void
    {
        Schema::table('transactions', function (Blueprint $table) {
            $table->dropIndex('transactions_user_goal_idx');
            $table->dropConstrainedForeignId('saving_goal_id');
        });
    }
};
