<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Music Player Orchestrator — Provider Services
    |--------------------------------------------------------------------------
    */

    'youtube' => [
        'api_key'     => env('YOUTUBE_API_KEY'),
        'base_url'    => 'https://www.googleapis.com/youtube/v3',
        'search_limit' => 20,
    ],

    'jamendo' => [
        'client_id' => env('JAMENDO_CLIENT_ID', '709fa152'),
        'base_url'  => 'https://api.jamendo.com/v3.0',
    ],

    'audius' => [
        'base_url' => 'https://api.audius.co/v1',
        'app_name' => env('APP_NAME', 'MusicPlayerOrchestrator'),
    ],

    'itunes' => [
        'base_url' => 'https://itunes.apple.com',
        'country'  => 'ID',
    ],

    'ytdlp' => [
        'path'    => env('YTDLP_PATH', 'yt-dlp'),
        'timeout' => 15, // detik maksimal tunggu yt-dlp
    ],

];
