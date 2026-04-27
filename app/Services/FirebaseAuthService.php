<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Auth as FirebaseAuth;
use Kreait\Firebase\Auth\SignInResult\SignInResult;
use Kreait\Firebase\Exception\Auth\FailedToVerifyToken;
use Kreait\Firebase\Exception\Auth\RevokedIdToken;
use Lcobucci\JWT\UnencryptedToken;
use Throwable;

class FirebaseAuthService
{
    public function __construct(protected ?FirebaseAuth $auth = null)
    {
        if ($this->auth === null) {
            try {
                $this->auth = app('firebase.auth');
            } catch (Throwable $e) {
                Log::warning('Firebase Auth unavailable: '.$e->getMessage());
                $this->auth = null;
            }
        }
    }

    public function isAvailable(): bool
    {
        return $this->auth instanceof FirebaseAuth;
    }

    /**
     * Verify a Firebase ID token and return its claims.
     *
     * @throws FailedToVerifyToken|RevokedIdToken
     */
    public function verifyIdToken(string $idToken): UnencryptedToken
    {
        if (! $this->isAvailable()) {
            throw new \RuntimeException('Firebase Auth is not configured.');
        }

        return $this->auth->verifyIdToken($idToken, checkIfRevoked: true);
    }

    /**
     * Find or create a local user from a verified Firebase ID token.
     * Returns [User, bool $wasJustCreated].
     *
     * @return array{0: User, 1: bool}
     */
    public function loginOrRegister(string $idToken, array $extra = []): array
    {
        $token = $this->verifyIdToken($idToken);
        $claims = $token->claims();

        $firebaseUid = $claims->get('sub');
        $phone = $claims->get('phone_number');
        $email = $claims->get('email');
        $name = $claims->get('name');

        if (! $phone && ! $email) {
            throw new \RuntimeException('Firebase token has no phone_number nor email — cannot link to a user.');
        }

        $user = $this->findExistingUser($phone, $email, $firebaseUid);
        $created = false;

        if (! $user) {
            $user = User::create([
                'name' => $name ?? ($extra['name'] ?? ($phone ? 'مستخدم Waffer' : 'Waffer User')),
                'phone' => $phone,
                'email' => $email,
                'monthly_income' => Arr::get($extra, 'monthly_income'),
                'currency' => Arr::get($extra, 'currency', 'SAR'),
                'language' => Arr::get($extra, 'language', app()->getLocale()),
                'is_active' => true,
            ]);
            $created = true;
        }

        $user->forceFill([
            'phone_verified_at' => $phone ? ($user->phone_verified_at ?? now()) : $user->phone_verified_at,
            'email_verified_at' => $email ? ($user->email_verified_at ?? now()) : $user->email_verified_at,
        ])->save();

        return [$user->fresh(), $created];
    }

    protected function findExistingUser(?string $phone, ?string $email, ?string $firebaseUid): ?User
    {
        if ($phone) {
            $byPhone = User::where('phone', $phone)->first();
            if ($byPhone) {
                return $byPhone;
            }
        }

        if ($email) {
            $byEmail = User::where('email', $email)->first();
            if ($byEmail) {
                return $byEmail;
            }
        }

        return null;
    }
}
