<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

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
            'low_balance',
            'tip',
            'system',
            'admin_message'
        )");

        DB::statement("ALTER TABLE alerts MODIFY COLUMN severity ENUM(
            'info',
            'warning',
            'critical',
            'success'
        ) DEFAULT 'info'");
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
            'system'
        )");

        DB::statement("ALTER TABLE alerts MODIFY COLUMN severity ENUM(
            'info',
            'warning',
            'critical'
        ) DEFAULT 'info'");
    }
};
