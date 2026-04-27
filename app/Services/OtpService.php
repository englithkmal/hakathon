<?php

namespace App\Services;

use App\Models\DeviceToken;
use App\Models\OtpCode;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;

class OtpService
{
    public const EXPIRY_MINUTES = 2;

    public const RESEND_COOLDOWN_SECONDS = 60;

    public const MAX_ATTEMPTS = 5;

    public function __construct(protected ?FcmService $fcm = null)
    {
        $this->fcm ??= app(FcmService::class);
    }

    /**
     * Generate, store and dispatch an OTP code.
     *
     * @param  string|null  $deviceToken  Optional FCM token to push the OTP to (for new users without an account yet)
     * @param  string|null  $platform  android|ios|web (informational)
     * @param  string|null  $locale  ar|en for the push notification language
     */
    public function send(
        string $phone,
        string $purpose = 'login',
        ?string $deviceToken = null,
        ?string $platform = null,
        ?string $locale = null
    ): OtpCode {
        $this->ensureNotInCooldown($phone);

        $code = $this->generateCode();

        $otp = OtpCode::create([
            'phone' => $phone,
            'code' => $code,
            'purpose' => $purpose,
            'device_token' => $deviceToken,
            'platform' => $platform,
            'locale' => $locale,
            'expires_at' => Carbon::now()->addMinutes(self::EXPIRY_MINUTES),
        ]);

        $this->dispatchOtp($phone, $code, $purpose, $deviceToken, $platform, $locale);

        return $otp;
    }

    /**
     * Verify an OTP code.
     *
     * @param  bool  $consume  When false, the OTP remains valid (useful for the
     *                         registration flow where the same code is reused
     *                         by the subsequent /auth/register call).
     */
    public function verify(string $phone, string $code, string $purpose = 'login', bool $consume = true): bool
    {
        $otp = OtpCode::query()
            ->where('phone', $phone)
            ->where('purpose', $purpose)
            ->whereNull('used_at')
            ->latest()
            ->first();

        if (! $otp) {
            return false;
        }

        if (! $otp->isValid()) {
            return false;
        }

        $otp->incrementAttempts();

        if ($otp->code !== $code) {
            return false;
        }

        if ($consume) {
            $otp->markAsUsed();
        }

        return true;
    }

    public function getCooldownRemaining(string $phone): int
    {
        $latest = OtpCode::query()
            ->where('phone', $phone)
            ->latest()
            ->first();

        if (! $latest) {
            return 0;
        }

        // Carbon 3: pass absolute=true to always get a positive delta,
        // regardless of which side of "now" $created_at falls on.
        $secondsSinceLast = (int) $latest->created_at->diffInSeconds(Carbon::now(), true);

        return max(0, self::RESEND_COOLDOWN_SECONDS - $secondsSinceLast);
    }

    protected function ensureNotInCooldown(string $phone): void
    {
        $remaining = $this->getCooldownRemaining($phone);

        if ($remaining > 0) {
            abort(429, "Please wait {$remaining} seconds before requesting a new OTP.");
        }
    }

    protected function generateCode(): string
    {
        // Always random — no hardcoded codes (even in local).
        return str_pad((string) random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
    }

    /**
     * Dispatch the OTP to the user.
     *
     * Resolution order (first match wins):
     *   1) Raw device_token from request
     *        - If user exists → upsert it as an active DeviceToken for the user
     *        - Push directly to that token (works for both new + existing users)
     *   2) No raw token, but user has registered active DeviceTokens → push to all of them
     *   3) Otherwise → log only (dev visibility, no real channel available)
     */
    protected function dispatchOtp(
        string $phone,
        string $code,
        string $purpose,
        ?string $deviceToken = null,
        ?string $platform = null,
        ?string $locale = null
    ): void {
        $user = User::where('phone', $phone)->first();
        $effectiveLocale = $locale ?: ($user?->language ?? config('app.locale', 'ar'));

        // 1) Auto-register the incoming token for known users so we don't lose it.
        if ($deviceToken && $user) {
            $this->registerDeviceToken($user, $deviceToken, $platform, $effectiveLocale);
        }

        // Decide push channel:
        //   - If the request brought a fresh token → use it directly (most reliable)
        //   - Otherwise fall back to user's stored devices
        $useRawToken = (bool) $deviceToken;
        $channel = $useRawToken ? 'raw_push' : ($user ? 'user_devices' : 'log_only');

        Log::info("[OTP] phone={$phone} purpose={$purpose} code={$code} channel={$channel}");

        $result = $this->fcm->sendOtpPush(
            code: $code,
            user: $useRawToken ? null : $user,        // raw token wins; otherwise use stored devices
            rawToken: $useRawToken ? $deviceToken : null,
            locale: $effectiveLocale,
            purpose: $purpose,
        );

        Log::info('[OTP] push dispatch result', [
            'phone' => $phone,
            'result' => $result,
        ]);
    }

    /**
     * Persist the raw FCM token as a DeviceToken row for this user
     * (or reactivate it if it already exists).
     */
    protected function registerDeviceToken(User $user, string $token, ?string $platform, string $locale): void
    {
        DeviceToken::updateOrCreate(
            ['token' => $token],
            [
                'user_id' => $user->id,
                'platform' => $platform ?? 'unknown',
                'locale' => $locale,
                'is_active' => true,
                'failed_at' => null,
                'failure_count' => 0,
                'last_used_at' => now(),
            ]
        );
    }
}
