<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Token authentication that never redirects.
 *
 * Laravel's default Authenticate middleware calls redirectTo('login') for
 * guests on requests that don't "expect JSON", which throws
 * RouteNotFoundException on an API-only app with no login route. This
 * middleware replaces auth:sanctum entirely so every unauthenticated/
 * invalid-token request gets a clean 401 JSON response instead.
 */
class AuthenticateWithToken
{
    public function handle(Request $request, Closure $next)
    {
        $token = $this->resolveToken($request);

        if (! $token) {
            return $this->deny('No token provided');
        }

        $pat = PersonalAccessToken::findToken($token);

        if (! $pat) {
            return $this->deny('Invalid token');
        }

        if ($pat->expires_at && $pat->expires_at->isPast()) {
            return $this->deny('Token expired');
        }

        $user = $pat->tokenable;

        if (! $user) {
            return $this->deny('User not found');
        }

        $pat->forceFill(['last_used_at' => now()])->save();

        $user->withAccessToken($pat);
        $request->setUserResolver(fn () => $user);

        return $next($request);
    }

    private function resolveToken(Request $request): ?string
    {
        if ($v = $request->header('X-Auth-Token')) {
            return trim($v);
        }

        foreach ([
            'HTTP_AUTHORIZATION',
            'REDIRECT_HTTP_AUTHORIZATION',
            'HTTP_X_AUTH_TOKEN',
            'REDIRECT_HTTP_X_AUTH_TOKEN',
        ] as $key) {
            $v = $_SERVER[$key] ?? '';
            if ($v) {
                if (stripos($v, 'Bearer ') === 0) {
                    return trim(substr($v, 7));
                }
                if (! empty($v) && stripos($v, 'Bearer ') === false) {
                    return trim($v);
                }
            }
        }

        $auth = $request->header('Authorization', '');
        if (is_string($auth) && stripos($auth, 'Bearer ') === 0) {
            return trim(substr($auth, 7));
        }

        if ($v = $request->query('api_token')) {
            return trim((string) $v);
        }

        return null;
    }

    private function deny(string $reason = ''): JsonResponse
    {
        return response()->json([
            'success' => false,
            'message' => 'يجب تسجيل الدخول أولاً',
            'debug'   => app()->hasDebugModeEnabled() ? $reason : null,
        ], 401);
    }
}
