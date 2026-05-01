<?php

namespace App\Services;

use App\Models\Alert;
use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Exception\Messaging\NotFound;
use Kreait\Firebase\Messaging\AndroidConfig;
use Kreait\Firebase\Messaging\ApnsConfig;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification as FcmNotification;
use Throwable;

class FcmService
{
    public function __construct(protected ?Messaging $messaging = null)
    {
        if ($this->messaging === null && $this->isEnabled()) {
            try {
                $this->messaging = app('firebase.messaging');
            } catch (Throwable $e) {
                Log::warning('FCM messaging unavailable: '.$e->getMessage());
                $this->messaging = null;
            }
        }
    }

    public function isEnabled(): bool
    {
        return (bool) config('fcm.enabled', false);
    }

    /**
     * Map stored/UI severity to FCM transport priority (Android/iOS).
     * Only warning|critical get high priority; everything else maps to warning so delivery matches OTP reliability.
     */
    public static function mapTransportSeverity(?string $severity): string
    {
        $s = (string) $severity;

        return in_array($s, ['warning', 'critical'], true) ? $s : 'warning';
    }

    /**
     * Send a notification to all active devices belonging to a user.
     * Uses the user's locale to localize the title/body.
     *
     * @return array{sent:int, failed:int}
     */
    public function sendToUser(User $user, array $payload): array
    {
        $tokens = $user->activeDeviceTokens()->get();

        if ($tokens->isEmpty()) {
            return ['sent' => 0, 'failed' => 0];
        }

        return $this->sendToTokens($tokens, $payload, $user);
    }

    /**
     * Send a localized notification derived from an Alert record.
     */
    public function sendForAlert(Alert $alert): array
    {
        $alert->loadMissing('user');

        if (! $alert->user) {
            return ['sent' => 0, 'failed' => 0];
        }

        $transportSeverity = self::mapTransportSeverity($alert->severity);

        $payload = [
            'title_ar' => $alert->title_ar,
            'title_en' => $alert->title_en,
            'body_ar' => $alert->message_ar,
            'body_en' => $alert->message_en,
            'data' => [
                'notification_id' => (string) $alert->id,
                'alert_id' => (string) $alert->id,
                'alert_type' => (string) $alert->type,
                'severity' => (string) $alert->severity,
                'deeplink' => (string) ($alert->deeplink ?? ''),
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            ],
            'severity' => $transportSeverity,
        ];

        return $this->sendToUser($alert->user, $payload);
    }

    /**
     * Broadcast a notification to a list of users (e.g. all admins, all active users).
     */
    public function sendToUsers(Collection $users, array $payload): array
    {
        $stats = ['sent' => 0, 'failed' => 0];

        foreach ($users as $user) {
            $result = $this->sendToUser($user, $payload);
            $stats['sent'] += $result['sent'];
            $stats['failed'] += $result['failed'];
        }

        return $stats;
    }

    /**
     * Push to devices registered without an account (onboarding / guest installs).
     *
     * @return array{sent:int, failed:int}
     */
    public function sendToGuestDevices(array $payload): array
    {
        $tokens = DeviceToken::query()
            ->guest()
            ->where('is_active', true)
            ->get();

        if ($tokens->isEmpty()) {
            return ['sent' => 0, 'failed' => 0];
        }

        return $this->sendToTokens($tokens, $payload, null);
    }

    /**
     * Merge guest push stats into cumulative broadcast stats.
     *
     * @param  array{sent:int, failed:int}  $stats
     * @return array{sent:int, failed:int}
     */
    public function mergeGuestPushStats(array $stats, array $payload): array
    {
        $guest = $this->sendToGuestDevices($payload);

        return [
            'sent' => $stats['sent'] + $guest['sent'],
            'failed' => $stats['failed'] + $guest['failed'],
        ];
    }

    /**
     * Send to a raw collection of DeviceToken models.
     *
     * Payload keys:
     *   - title_ar / title_en   (required, localization-aware)
     *   - body_ar / body_en     (required)
     *   - data                  (optional array, all values cast to string)
     *   - severity              (optional, drives Android channel/priority)
     */
    public function sendToTokens(Collection $tokens, array $payload, ?User $user = null): array
    {
        if (! $this->isEnabled() || $this->messaging === null) {
            Log::info('FCM is disabled — skipping push send.', [
                'user_id' => $user?->id,
                'tokens' => $tokens->count(),
            ]);

            return ['sent' => 0, 'failed' => 0];
        }

        $sent = 0;
        $failed = 0;

        foreach ($tokens as $deviceToken) {
            /** @var DeviceToken $deviceToken */
            $locale = $deviceToken->locale ?: ($user?->language ?? config('app.locale'));

            $title = $locale === 'en'
                ? ($payload['title_en'] ?? $payload['title_ar'] ?? 'Waffer')
                : ($payload['title_ar'] ?? $payload['title_en'] ?? 'وفر');

            $body = $locale === 'en'
                ? ($payload['body_en'] ?? $payload['body_ar'] ?? '')
                : ($payload['body_ar'] ?? $payload['body_en'] ?? '');

            $message = $this->buildMessage(
                token: $deviceToken->token,
                title: $title,
                body: $body,
                data: $this->normalizeData($payload['data'] ?? []),
                severity: $payload['severity'] ?? 'info',
            );

            try {
                $this->messaging->send($message);
                $deviceToken->markUsed();
                $sent++;
            } catch (NotFound $e) {
                $deviceToken->markFailed('token_not_registered');
                $deviceToken->forceFill(['is_active' => false])->save();
                $failed++;
                Log::info('FCM token deactivated (not registered).', [
                    'device_token_id' => $deviceToken->id,
                ]);
            } catch (Throwable $e) {
                $deviceToken->markFailed($e->getMessage());
                $failed++;
                Log::warning('FCM send failed.', [
                    'device_token_id' => $deviceToken->id,
                    'error' => $e->getMessage(),
                ]);
            }
        }

        return ['sent' => $sent, 'failed' => $failed];
    }

    /**
     * Send a one-time push notification to a raw FCM token (no DeviceToken record needed).
     * Used for OTP delivery to brand-new users that don't have a registered device yet.
     *
     * @return array{sent:int, failed:int, error?:string}
     */
    public function sendToRawToken(string $token, array $payload, string $locale = 'ar'): array
    {
        if (! $this->isEnabled() || $this->messaging === null) {
            Log::info('FCM disabled — cannot deliver OTP push.', ['token_preview' => substr($token, 0, 12).'...']);

            return ['sent' => 0, 'failed' => 1, 'error' => 'fcm_disabled'];
        }

        $title = $locale === 'en'
            ? ($payload['title_en'] ?? $payload['title_ar'] ?? 'Waffer')
            : ($payload['title_ar'] ?? $payload['title_en'] ?? 'وفر');

        $body = $locale === 'en'
            ? ($payload['body_en'] ?? $payload['body_ar'] ?? '')
            : ($payload['body_ar'] ?? $payload['body_en'] ?? '');

        $message = $this->buildMessage(
            token: $token,
            title: $title,
            body: $body,
            data: $this->normalizeData($payload['data'] ?? []),
            severity: $payload['severity'] ?? 'info',
        );

        try {
            $this->messaging->send($message);

            return ['sent' => 1, 'failed' => 0];
        } catch (NotFound $e) {
            Log::warning('FCM raw token not registered.', ['token_preview' => substr($token, 0, 12).'...']);

            return ['sent' => 0, 'failed' => 1, 'error' => 'token_not_registered'];
        } catch (Throwable $e) {
            Log::warning('FCM raw send failed.', ['error' => $e->getMessage()]);

            return ['sent' => 0, 'failed' => 1, 'error' => $e->getMessage()];
        }
    }

    /**
     * Send an OTP code as a push notification.
     * Works either with an authenticated User (uses their active device tokens)
     * or with a raw FCM token passed directly (for new users / pre-registration).
     *
     * @return array{sent:int, failed:int, channel:string}
     */
    public function sendOtpPush(
        string $code,
        ?User $user = null,
        ?string $rawToken = null,
        string $locale = 'ar',
        string $purpose = 'login'
    ): array {
        $isLogin = $purpose === 'login';

        $payload = [
            'title_ar' => $isLogin ? 'رمز تسجيل الدخول' : 'رمز التحقق',
            'title_en' => $isLogin ? 'Sign-in code' : 'Verification code',
            'body_ar' => "رمزك هو: {$code} — صالح لمدة دقيقتين",
            'body_en' => "Your code: {$code} — valid for 2 minutes",
            'data' => [
                'type' => 'otp',
                'code' => $code,
                'purpose' => $purpose,
                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
            ],
            'severity' => 'critical',
        ];

        if ($user !== null) {
            $stats = $this->sendToUser($user, $payload);

            return $stats + ['channel' => 'user_devices'];
        }

        if ($rawToken !== null) {
            $stats = $this->sendToRawToken($rawToken, $payload, $locale);

            return $stats + ['channel' => 'raw_token'];
        }

        return ['sent' => 0, 'failed' => 0, 'channel' => 'none'];
    }

    protected function buildMessage(string $token, string $title, string $body, array $data, string $severity): CloudMessage
    {
        $priority = in_array($severity, ['warning', 'critical'], true) ? 'high' : 'normal';

        $androidConfig = AndroidConfig::fromArray([
            'priority' => $priority,
            'ttl' => config('fcm.ttl_seconds', 3600).'s',
            'notification' => [
                'channel_id' => config('fcm.android_channel_id', 'waffer_alerts'),
                'sound' => 'default',
            ],
        ]);

        $apnsConfig = ApnsConfig::fromArray([
            'headers' => [
                'apns-priority' => $priority === 'high' ? '10' : '5',
            ],
            'payload' => [
                'aps' => [
                    'sound' => config('fcm.default_sound', 'default'),
                    'badge' => 1,
                    'content-available' => 1,
                ],
            ],
        ]);

        return CloudMessage::withTarget('token', $token)
            ->withNotification(FcmNotification::create($title, $body))
            ->withData($data)
            ->withAndroidConfig($androidConfig)
            ->withApnsConfig($apnsConfig);
    }

    protected function normalizeData(array $data): array
    {
        $normalized = [];
        foreach ($data as $key => $value) {
            $normalized[(string) $key] = is_scalar($value) || $value === null
                ? (string) $value
                : json_encode($value, JSON_UNESCAPED_UNICODE);
        }

        return $normalized;
    }
}
