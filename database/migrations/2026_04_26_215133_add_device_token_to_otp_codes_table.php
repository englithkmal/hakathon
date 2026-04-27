<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('otp_codes', function (Blueprint $table) {
            // FCM token of the device that requested the OTP — used to send the OTP
            // as a push notification (especially for new users that don't have an
            // active device token registered yet under any user_id).
            $table->string('device_token', 512)->nullable()->after('purpose');
            $table->string('platform', 16)->nullable()->after('device_token');
            $table->string('locale', 2)->nullable()->after('platform');
        });
    }

    public function down(): void
    {
        Schema::table('otp_codes', function (Blueprint $table) {
            $table->dropColumn(['device_token', 'platform', 'locale']);
        });
    }
};
