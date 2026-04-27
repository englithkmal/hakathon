<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\FirebaseLoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\SendOtpRequest;
use App\Http\Requests\Auth\UpdateProfileRequest;
use App\Http\Requests\Auth\VerifyOtpRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\FirebaseAuthService;
use App\Services\OtpService;
use App\Traits\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Kreait\Firebase\Exception\Auth\FailedToVerifyToken;
use Kreait\Firebase\Exception\Auth\RevokedIdToken;
use Throwable;

class AuthController extends Controller
{
    use ApiResponse;

    public function __construct(
        protected OtpService $otpService,
        protected FirebaseAuthService $firebaseAuth,
    ) {}

    /**
     * Login or register the user using a Firebase ID token (e.g. issued by Firebase Phone Auth).
     *
     * The Flutter client handles the SMS OTP flow with Firebase directly,
     * then ships the resulting ID token here. We verify it and issue a Sanctum token.
     */
    public function firebaseLogin(FirebaseLoginRequest $request): JsonResponse
    {
        if (! $this->firebaseAuth->isAvailable()) {
            return $this->errorResponse('خدمة Firebase غير متوفرة في السيرفر حالياً', 503);
        }

        try {
            [$user, $created] = $this->firebaseAuth->loginOrRegister(
                $request->input('id_token'),
                $request->only(['name', 'monthly_income', 'currency', 'language']),
            );
        } catch (RevokedIdToken) {
            return $this->errorResponse('انتهت صلاحية الجلسة، أعد تسجيل الدخول', 401);
        } catch (FailedToVerifyToken) {
            return $this->errorResponse('رمز Firebase غير صالح', 401);
        } catch (Throwable $e) {
            return $this->errorResponse('فشل التحقق: '.$e->getMessage(), 422);
        }

        if (! $user->is_active) {
            return $this->errorResponse('هذا الحساب معطّل', 403);
        }

        return $this->successResponse([
            'user' => new UserResource($user),
            'token' => $user->createToken('mobile')->plainTextToken,
            'is_new_user' => $created,
        ], $created ? 'تم إنشاء الحساب وتسجيل الدخول' : 'تم تسجيل الدخول بنجاح', $created ? 201 : 200);
    }

    /**
     * Smart OTP dispatcher.
     *
     * The client only sends the phone number; the backend automatically
     * decides whether this is a login (existing user) or registration flow.
     */
    public function sendOtp(SendOtpRequest $request): JsonResponse
    {
        $phone = $request->input('phone');

        $user = User::where('phone', $phone)->first();
        $purpose = $user ? 'login' : 'register';

        if ($user && ! $user->is_active) {
            return $this->errorResponse('هذا الحساب معطّل', 403);
        }

        $cooldown = $this->otpService->getCooldownRemaining($phone);
        if ($cooldown > 0) {
            return $this->errorResponse(
                "يرجى الانتظار {$cooldown} ثانية قبل طلب رمز جديد",
                429,
                ['cooldown' => $cooldown]
            );
        }

        $this->otpService->send(
            phone: $phone,
            purpose: $purpose,
            deviceToken: $request->input('device_token'),
            platform: $request->input('platform'),
            locale: $request->input('locale', $user?->language),
        );

        $hasPushChannel = (bool) $request->input('device_token')
            || ($user && $user->activeDeviceTokens()->exists());

        return $this->successResponse([
            'is_new_user' => ! $user,
            'expires_in' => OtpService::EXPIRY_MINUTES * 60,
            'cooldown_seconds' => OtpService::RESEND_COOLDOWN_SECONDS,
            'delivery' => $hasPushChannel ? 'push' : 'log',
            'hint' => $hasPushChannel
                ? 'الرمز تم إرساله كإشعار على جهازك'
                : 'لا يوجد جهاز مسجّل — الرمز محفوظ في السجل (للتطوير فقط)',
        ], $user ? 'تم إرسال رمز تسجيل الدخول' : 'تم إرسال رمز التحقق لإنشاء حساب');
    }

    /**
     * Smart OTP verifier.
     *
     * - If the phone belongs to an existing active user → log them in (consume OTP).
     * - Otherwise → mark the OTP as verified but DO NOT consume it,
     *   so /auth/register can reuse the same code right after.
     */
    public function verifyOtp(VerifyOtpRequest $request): JsonResponse
    {
        $phone = $request->input('phone');
        $code = $request->input('code');

        $user = User::where('phone', $phone)->first();
        $isNewUser = ! $user;
        $purpose = $isNewUser ? 'register' : 'login';

        $verified = $this->otpService->verify($phone, $code, $purpose, consume: ! $isNewUser);

        if (! $verified) {
            return $this->errorResponse('رمز التحقق غير صحيح أو منتهي', 422);
        }

        if (! $isNewUser) {
            if (! $user->is_active) {
                return $this->errorResponse('هذا الحساب معطّل', 403);
            }

            $user->forceFill(['phone_verified_at' => now()])->save();

            return $this->successResponse([
                'user' => new UserResource($user),
                'token' => $user->createToken('mobile')->plainTextToken,
                'is_new_user' => false,
            ], 'تم تسجيل الدخول بنجاح');
        }

        return $this->successResponse([
            'verified' => true,
            'is_new_user' => true,
        ], 'تم التحقق، أكمل بيانات التسجيل');
    }

    public function register(RegisterRequest $request): JsonResponse
    {
        $phone = $request->input('phone');
        $code = $request->input('code');

        if (! $this->otpService->verify($phone, $code, 'register')) {
            return $this->errorResponse('رمز التحقق غير صحيح أو منتهي', 422);
        }

        $user = User::create([
            'name' => $request->input('name'),
            'phone' => $phone,
            'email' => $request->input('email'),
            'monthly_income' => $request->input('monthly_income'),
            'currency' => $request->input('currency', 'SAR'),
            'language' => $request->input('language', 'ar'),
            'is_active' => true,
        ]);

        $user->forceFill(['phone_verified_at' => now()])->save();

        return $this->successResponse([
            'user' => new UserResource($user),
            'token' => $user->createToken('mobile')->plainTextToken,
        ], 'تم إنشاء الحساب بنجاح', 201);
    }

    public function me(Request $request): JsonResponse
    {
        return $this->successResponse(new UserResource($request->user()));
    }

    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        $user = $request->user();

        $user->update($request->validated());

        if ($request->has('language')) {
            app()->setLocale($user->language);
        }

        return $this->successResponse(
            new UserResource($user->fresh()),
            'تم تحديث الملف الشخصي'
        );
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return $this->successResponse(null, 'تم تسجيل الخروج');
    }

    public function logoutAll(Request $request): JsonResponse
    {
        $request->user()->tokens()->delete();

        return $this->successResponse(null, 'تم تسجيل الخروج من جميع الأجهزة');
    }
}
