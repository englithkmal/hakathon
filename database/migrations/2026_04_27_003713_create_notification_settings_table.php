<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('notification_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique()->comment('Unique slug, e.g. daily_tip');
            $table->string('label_ar');
            $table->string('label_en');
            $table->string('description_ar')->nullable();
            $table->string('description_en')->nullable();
            $table->string('command')->comment('Artisan command to invoke, e.g. waffer:daily-tip');
            $table->boolean('is_enabled')->default(true);
            $table->time('schedule_time')->nullable()->comment('HH:MM in app timezone');
            $table->string('schedule_frequency')->default('daily')->comment('daily | monthly | manual');
            $table->unsignedTinyInteger('schedule_day_of_month')->nullable()->comment('Used when frequency=monthly');
            $table->json('extra_config')->nullable()->comment('e.g. {"days":7} for goal-deadline');
            $table->timestamp('last_run_at')->nullable();
            $table->json('last_run_stats')->nullable();
            $table->string('last_run_status', 16)->nullable()->comment('success | failed');
            $table->timestamps();

            $table->index(['is_enabled', 'schedule_frequency']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_settings');
    }
};
