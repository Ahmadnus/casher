<?php

use App\Http\Middleware\EnsureUserIsActive;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Request as SymfonyRequest;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {

      $middleware->alias([
        'active' => EnsureUserIsActive::class,
    ]);

        // ngrok terminates TLS and proxies to us over plain HTTP, forwarding
        // the real client IP/proto in X-Forwarded-*. Without trusting it,
        // every request appears to come from ngrok's own IP, which breaks
        // per-client rate limiting and IP logging (AuthController::login).
        $middleware->trustProxies(
            at: '*',
            headers: SymfonyRequest::HEADER_X_FORWARDED_FOR
                | SymfonyRequest::HEADER_X_FORWARDED_HOST
                | SymfonyRequest::HEADER_X_FORWARDED_PORT
                | SymfonyRequest::HEADER_X_FORWARDED_PROTO,
        );

        // Global fallback throttle for every /api/* route. Routes below
        // still layer stricter, endpoint-specific limits on top.
        $middleware->throttleApi();

        // This is an API-only app: there is no "login" web route to redirect
        // guests to. Without this, an unauthenticated/expired-token request
        // to any api/* route throws RouteNotFoundException("Route [login]
        // not defined") instead of a clean 401 JSON response.
        $middleware->redirectGuestsTo(
            fn (Request $request) => $request->is('api/*') ? null : '/login',
        );
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*'),
        );
    })->create();
