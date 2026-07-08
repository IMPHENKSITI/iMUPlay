<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\HealthController;
use App\Http\Controllers\Api\SearchController;
use App\Http\Controllers\Api\StreamUrlController;
use App\Http\Controllers\Api\ThumbnailProxyController;
use App\Http\Controllers\Api\ArtistController;
use App\Http\Controllers\Api\AlbumController;
use App\Http\Controllers\Api\SyncController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes — iMUplay Music Player (V2 - Auth Edition)
|--------------------------------------------------------------------------
|
| Laravel — semua route di sini prefix /api secara otomatis
| via bootstrap/app.php withRouting(api: ...)
|
*/

// ─── PUBLIK (Tanpa Auth) ─────────────────────────────────────────────────────

// Health check — cek status semua provider & yt-dlp
Route::get('/health', HealthController::class);

// Proxy thumbnail — tidak perlu auth, aman untuk di-cache
Route::get('/proxy/thumbnail', ThumbnailProxyController::class);

// Auth routes
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login',    [AuthController::class, 'login']);


// ─── PROTECTED (Wajib Bearer Token / auth:sanctum) ───────────────────────────

Route::middleware('auth:sanctum')->group(function () {

    // Auth — info user & logout
    Route::get('/auth/me',       [AuthController::class, 'me']);
    Route::post('/auth/logout',  [AuthController::class, 'logout']);

    // Search musik — dikunci untuk user yang sudah login
    Route::get('/search', SearchController::class);

    // Resolve stream URL — dikunci untuk user yang sudah login
    Route::get('/stream-url', StreamUrlController::class);

    // Artist & Album Profile
    Route::get('/artist/{name}', [ArtistController::class, 'show']);
    Route::get('/album/{id}',    [AlbumController::class, 'show']);

    // Cloud Sync — push dari Flutter ke server
    Route::post('/sync', [SyncController::class, 'sync']);

    // Cloud Pull — tarik data dari server ke Flutter (misal saat login di device baru)
    Route::get('/sync', [SyncController::class, 'pull']);
});

