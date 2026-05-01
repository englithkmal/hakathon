<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-user immutable snapshot of how a calendar month ended (BR-06).
 * Created by `waffer:close-month` cron on day 1 of the next month, or
 * manually from Filament. Reports/dashboards read from this table for
 * historical months instead of re-aggregating transactions on the fly,
 * so editing an old transaction does not rewrite history.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('monthly_summaries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();

            $table->unsignedTinyInteger('month');
            $table->unsignedSmallInteger('year');
            $table->date('period_start');
            $table->date('period_end');

            // Cash flow snapshot (pulled from transactions at close time).
            $table->decimal('total_income', 12, 2)->default(0);
            $table->decimal('total_expenses', 12, 2)->default(0);
            $table->decimal('total_goal_deposits', 12, 2)->default(0);
            // unallocated = income − expenses − goal_deposits  (BR-04 "وفر الشهر")
            $table->decimal('unallocated_savings', 12, 2)->default(0);
            $table->unsignedInteger('transaction_count')->default(0);

            // Budget snapshot (kept even if the budget row is later deleted).
            $table->foreignId('budget_id')->nullable()->constrained()->nullOnDelete();
            $table->decimal('budget_total_amount', 12, 2)->nullable();
            $table->decimal('budget_total_spent', 12, 2)->nullable();
            $table->decimal('budget_adherence_pct', 6, 2)->nullable();

            // Top expense categories (top 3): [{category_id, name_ar, name_en, total, count, percentage}]
            $table->json('top_categories')->nullable();

            // Allocation tracking — how much of `unallocated_savings` was later
            // moved into saving goals via POST /monthly-summaries/{id}/allocate.
            $table->enum('allocation_status', [
                'unallocated',
                'partially_allocated',
                'fully_allocated',
            ])->default('unallocated');
            $table->decimal('allocated_amount', 12, 2)->default(0);

            $table->timestamp('closed_at')->useCurrent();
            $table->enum('closed_by', ['cron', 'manual'])->default('cron');
            $table->text('notes')->nullable();

            $table->timestamps();

            $table->unique(['user_id', 'year', 'month'], 'monthly_summaries_user_period_unique');
            $table->index(['user_id', 'closed_at'], 'monthly_summaries_user_closed_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('monthly_summaries');
    }
};
