<?php

/*
|--------------------------------------------------------------------------
| CORS — locked down for a native-app-only API
|--------------------------------------------------------------------------
| The Flutter POS app is a native client and never sends an Origin
| header, so CORS does not apply to it at all. Allowing zero origins
| simply means no *browser* page on any other website can call this
| API with a user's credentials. If a web dashboard is ever added,
| list its exact origin in allowed_origins.
*/

return [
    'paths' => ['api/*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => [],
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
