<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Laravel\Sanctum\PersonalAccessToken;
use Symfony\Component\HttpFoundation\Response;

/**
 * يضبط locale للـ API قبل الـ Resources:
 * 1) لغة المستخدم إن وُجد توكن Sanctum صالح
 * 2) وإلا Accept-Language
 * 3) وإلا ar (وليس en) لتفادي ظهور إنجليزي افتراضي في تطبيق عربي.
 */
class SetApiLocale
{
    protected array $supported = ['ar', 'en'];

    public function handle(Request $request, Closure $next): Response
    {
        $locale = $this->resolveLocale($request);

        if (! in_array($locale, $this->supported, true)) {
            $locale = 'ar';
        }

        app()->setLocale($locale);

        return $next($request);
    }

    protected function resolveLocale(Request $request): string
    {
        $token = $request->bearerToken();
        if ($token) {
            $access = PersonalAccessToken::findToken($token);
            $user = $access?->tokenable;
            if ($user instanceof User && in_array((string) $user->language, $this->supported, true)) {
                return (string) $user->language;
            }
        }

        $header = $request->header('Accept-Language');
        if ($header) {
            $first = strtolower(trim(strtok($header, ',')));
            $tag = strtok($first, '-;');
            if ($tag === 'en') {
                return 'en';
            }
            if ($tag !== false && str_starts_with($tag, 'ar')) {
                return 'ar';
            }
        }

        $fallback = config('app.locale', 'ar');

        return in_array($fallback, $this->supported, true) ? $fallback : 'ar';
    }
}
