<?php

return [
    /*
    |--------------------------------------------------------------------------
    | FCM Master Switch
    |--------------------------------------------------------------------------
    |
    | When false, every push attempt is silently skipped.
    | Useful in local/testing environments.
    */
    'enabled' => env('FCM_ENABLED', true),

    /*
    |--------------------------------------------------------------------------
    | Project ID (informational only — credentials decide the real target)
    |--------------------------------------------------------------------------
    */
    'project_id' => env('FIREBASE_PROJECT_ID'),

    /*
    |--------------------------------------------------------------------------
    | Default notification channel (Android)
    |--------------------------------------------------------------------------
    */
    'android_channel_id' => env('FCM_ANDROID_CHANNEL', 'waffer_alerts'),

    /*
    |--------------------------------------------------------------------------
    | Default sound (iOS)
    |--------------------------------------------------------------------------
    */
    'default_sound' => env('FCM_DEFAULT_SOUND', 'default'),

    /*
    |--------------------------------------------------------------------------
    | Time-to-live for messages (seconds)
    |--------------------------------------------------------------------------
    */
    'ttl_seconds' => env('FCM_TTL_SECONDS', 3600),
];
