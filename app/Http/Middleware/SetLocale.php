<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SetLocale
{
    protected array $supported = ['ar', 'en'];

    public function handle(Request $request, Closure $next): Response
    {
        $locale = $request->query('lang')
            ?? $request->session()->get('admin_locale')
            ?? config('app.locale');

        if (! in_array($locale, $this->supported, true)) {
            $locale = 'ar';
        }

        if ($request->has('lang')) {
            $request->session()->put('admin_locale', $locale);
        }

        app()->setLocale($locale);

        return $next($request);
    }
}
