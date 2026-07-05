<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Temporary debug route — inspect what the server passes through for the
// Authorization header. Remove once the cPanel header-stripping issue is
// confirmed fixed.
Route::get('/debug-headers', function () {
    return response()->json([
        'getallheaders' => function_exists('getallheaders') ? getallheaders() : 'unavailable',
        'apache_request_headers' => function_exists('apache_request_headers') ? apache_request_headers() : 'unavailable',
        'server_auth_keys' => array_filter($_SERVER, fn ($k) => str_contains($k, 'AUTH'), ARRAY_FILTER_USE_KEY),
        'laravel_header' => request()->header('Authorization'),
        'sapi' => php_sapi_name(),
    ]);
});
