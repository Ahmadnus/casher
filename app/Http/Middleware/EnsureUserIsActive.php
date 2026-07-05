<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * An admin can deactivate an employee at any time (e.g. they left the
 * job). Without this middleware, a previously-issued Sanctum token would
 * keep working until manually revoked. This guarantees deactivation
 * takes effect immediately on the very next request.
 */
class EnsureUserIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && ! $user->is_active) {
            $user->currentAccessToken()?->delete();

            return response()->json([
                'success' => false,
                'message' => 'تم تعطيل هذا الحساب. يرجى التواصل مع الإدارة',
            ], Response::HTTP_FORBIDDEN);
        }

        return $next($request);
    }
}