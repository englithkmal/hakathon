<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use App\Services\FcmService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class DeviceController extends Controller
{
    use ApiResponse;

    public function __construct(protected FcmService $fcm) {}

    /**
     * Register or refresh an FCM token for the authenticated user.
     */
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['required', Rule::in(['android', 'ios', 'web'])],
            'device_name' => ['nullable', 'string', 'max:255'],
            'device_model' => ['nullable', 'string', 'max:255'],
            'app_version' => ['nullable', 'string', 'max:50'],
            'locale' => ['nullable', Rule::in(['ar', 'en'])],
        ]);

        $user = $request->user();

        $deviceToken = DeviceToken::updateOrCreate(
            ['token' => $data['token']],
            [
                'user_id' => $user->id,
                'platform' => $data['platform'],
                'device_name' => $data['device_name'] ?? null,
                'device_model' => $data['device_model'] ?? null,
                'app_version' => $data['app_version'] ?? null,
                'locale' => $data['locale'] ?? $user->language ?? 'ar',
                'is_active' => true,
                'last_used_at' => now(),
                'failed_at' => null,
                'failure_count' => 0,
            ]
        );

        return $this->successResponse(
            [
                'device_token' => [
                    'id' => $deviceToken->id,
                    'platform' => $deviceToken->platform,
                    'locale' => $deviceToken->locale,
                    'is_active' => $deviceToken->is_active,
                    'last_used_at' => $deviceToken->last_used_at,
                ],
            ],
            'تم تسجيل التوكن بنجاح',
            201
        );
    }

    /**
     * Unregister a single token (e.g. on logout) for the authenticated user.
     */
    public function unregister(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
        ]);

        $deleted = DeviceToken::where('user_id', $request->user()->id)
            ->where('token', $data['token'])
            ->delete();

        return $this->successResponse(
            ['deleted' => (bool) $deleted],
            $deleted ? 'تم إلغاء تسجيل التوكن' : 'التوكن غير موجود'
        );
    }

    /**
     * List the authenticated user's registered devices.
     */
    public function index(Request $request): JsonResponse
    {
        $devices = $request->user()->deviceTokens()
            ->orderByDesc('last_used_at')
            ->get(['id', 'platform', 'device_name', 'device_model', 'app_version', 'locale', 'is_active', 'last_used_at']);

        return $this->successResponse(['devices' => $devices]);
    }

    /**
     * Send a test push notification to the current authenticated user's devices.
     */
    public function test(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['nullable', 'string', 'max:255'],
            'body' => ['nullable', 'string', 'max:1000'],
        ]);

        $result = $this->fcm->sendToUser($request->user(), [
            'title_ar' => $data['title'] ?? 'إشعار تجريبي من Waffer',
            'title_en' => $data['title'] ?? 'Waffer Test Notification',
            'body_ar' => $data['body'] ?? 'إذا شفت الإشعار، فالإعداد سليم.',
            'body_en' => $data['body'] ?? 'If you see this, FCM is wired correctly.',
            'data' => [
                'type' => 'test',
            ],
            'severity' => 'info',
        ]);

        return $this->successResponse(
            $result,
            'تم تنفيذ الإرسال (sent='.$result['sent'].', failed='.$result['failed'].')'
        );
    }

    /**
     * Register FCM token before login (e.g. during onboarding). Same token is
     * linked to the user automatically after authenticated POST devices/register.
     */
    public function registerGuest(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['required', Rule::in(['android', 'ios', 'web'])],
            'device_name' => ['nullable', 'string', 'max:255'],
            'device_model' => ['nullable', 'string', 'max:255'],
            'app_version' => ['nullable', 'string', 'max:50'],
            'locale' => ['nullable', Rule::in(['ar', 'en'])],
        ]);

        $deviceToken = DeviceToken::firstOrNew(['token' => $data['token']]);

        $payload = [
            'platform' => $data['platform'],
            'device_name' => $data['device_name'] ?? null,
            'device_model' => $data['device_model'] ?? null,
            'app_version' => $data['app_version'] ?? null,
            'locale' => $data['locale'] ?? 'ar',
            'is_active' => true,
            'last_used_at' => now(),
            'failed_at' => null,
            'failure_count' => 0,
        ];

        if ($deviceToken->exists && $deviceToken->user_id !== null) {
            $deviceToken->fill($payload)->save();
            $message = 'الجهاز مرتبط بحساب — تم تحديث بيانات الجهاز فقط';
            $code = 200;
        } else {
            $deviceToken->fill(array_merge($payload, ['user_id' => null]))->save();
            $message = 'تم تسجيل الجهاز لاستقبال الإشعارات العامة';
            $code = $deviceToken->wasRecentlyCreated ? 201 : 200;
        }

        return $this->successResponse(
            [
                'device_token' => [
                    'id' => $deviceToken->id,
                    'platform' => $deviceToken->platform,
                    'locale' => $deviceToken->locale,
                    'is_active' => $deviceToken->is_active,
                    'last_used_at' => $deviceToken->last_used_at,
                ],
            ],
            $message,
            $code
        );
    }
}
