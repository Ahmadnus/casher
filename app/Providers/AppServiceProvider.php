<?php

namespace App\Providers;

use App\Models\User;
use App\Policies\EmployeePolicy;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void {}

    public function boot(): void
    {
        // EmployeePolicy guards the User model, so auto-discovery
        // (User -> UserPolicy) never finds it; register it explicitly.
        Gate::policy(User::class, EmployeePolicy::class);

        // Force HTTPS URL generation in production (behind a reverse proxy).
        if ($this->app->environment('production')) {
            URL::forceScheme('https');
        }

        // Backs Middleware::throttleApi() in bootstrap/app.php — applies to
        // every /api/* route as a baseline ceiling.
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)
            ->by($request->user()?->id ?: $request->ip()));

        // Tighter limit for state-mutating POS actions (creating orders/
        // invoices, marking paid, etc.) so a compromised or buggy client
        // can't hammer the database once it's reachable over the internet.
        RateLimiter::for('pos-write', fn (Request $request) => Limit::perMinute(30)
            ->by($request->user()?->id ?: $request->ip()));
    }
}