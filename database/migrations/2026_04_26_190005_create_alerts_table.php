<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('alerts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('budget_category_id')->nullable()->constrained()->cascadeOnDelete();
            $table->foreignId('saving_goal_id')->nullable()->constrained()->cascadeOnDelete();
            $table->enum('type', [
                'threshold_50',
                'threshold_80',
                'threshold_100',
                'exceeded',
                'goal_progress',
                'goal_achieved',
                'low_balance',
                'tip',
                'system',
            ]);
            $table->enum('severity', ['info', 'warning', 'critical'])->default('info');
            $table->string('title_ar');
            $table->string('title_en');
            $table->text('message_ar');
            $table->text('message_en');
            $table->json('payload')->nullable();
            $table->boolean('is_read')->default(false);
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'is_read']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('alerts');
    }
};
