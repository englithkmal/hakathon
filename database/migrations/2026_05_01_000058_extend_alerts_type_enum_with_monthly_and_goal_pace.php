<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Extends `alerts.type` enum to support:
 *   - monthly_summary_ready : pushed when waffer:close-month produces a summary.
 *   - goal_off_track        : pushed when waffer:goal-pace-check finds a goal lagging.
 *
 * Strategy mirrors 2026_04_26_201343_alter_alerts_add_admin_message_type — full
 * MODIFY COLUMN with the complete set of values, since MySQL does not support
 * ENUM additions in-place.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE alerts MODIFY COLUMN type ENUM(
            'threshold_50',
            'threshold_80',
            'threshold_100',
            'exceeded',
            'goal_progress',
            'goal_achieved',
            'goal_off_track',
            'low_balance',
            'tip',
            'system',
            'admin_message',
            'monthly_summary_ready'
        )");
    }

    public function down(): void
    {
        DB::statement("ALTER TABLE alerts MODIFY COLUMN type ENUM(
            'threshold_50',
            'threshold_80',
            'threshold_100',
            'exceeded',
            'goal_progress',
            'goal_achieved',
            'low_balance',
            'tip',
            'system',
            'admin_message'
        )");
    }
};
