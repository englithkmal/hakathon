<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('alerts', function (Blueprint $table) {
            if (! Schema::hasColumn('alerts', 'icon')) {
                $table->string('icon')->nullable()->after('message_en');
            }

            if (! Schema::hasColumn('alerts', 'deeplink')) {
                $table->string('deeplink')->nullable()->after('icon');
            }

            $table->index(['user_id', 'is_read', 'created_at'], 'alerts_user_read_created_idx');
            $table->index(['user_id', 'created_at'], 'alerts_user_created_idx');
        });
    }

    public function down(): void
    {
        Schema::table('alerts', function (Blueprint $table) {
            $table->dropIndex('alerts_user_read_created_idx');
            $table->dropIndex('alerts_user_created_idx');

            if (Schema::hasColumn('alerts', 'deeplink')) {
                $table->dropColumn('deeplink');
            }

            if (Schema::hasColumn('alerts', 'icon')) {
                $table->dropColumn('icon');
            }
        });
    }
};
