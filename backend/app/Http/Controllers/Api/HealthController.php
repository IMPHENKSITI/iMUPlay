<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

class HealthController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $ytdlpPath    = config('services.ytdlp.path', 'yt-dlp');
        $ytdlpVersion = null;
        $ytdlpOk      = false;

        // Cek apakah yt-dlp bisa dipanggil dari sistem
        $output = shell_exec("{$ytdlpPath} --version 2>&1");
        if ($output && preg_match('/\d{4}\.\d+\.\d+/', trim($output), $matches)) {
            $ytdlpVersion = trim($matches[0]);
            $ytdlpOk      = true;
        }

        // Cek API keys sudah diset
        $youtubeKey   = config('services.youtube.api_key', '');
        $jamendoKey   = config('services.jamendo.client_id', '');

        $youtubeKeyOk = !empty($youtubeKey) && $youtubeKey !== 'PASTE_YOUTUBE_API_KEY_DISINI';
        $jamendoKeyOk = !empty($jamendoKey);

        return response()->json([
            'status'  => 'ok',
            'app'     => config('app.name'),
            'version' => '1.0.0',
            'providers' => [
                'youtube' => [
                    'api_key_set' => $youtubeKeyOk,
                    'available'   => $youtubeKeyOk,
                ],
                'audius' => [
                    'api_key_set' => true,   // tidak perlu key
                    'available'   => true,
                ],
                'jamendo' => [
                    'api_key_set' => $jamendoKeyOk,
                    'available'   => $jamendoKeyOk,
                ],
                'itunes' => [
                    'api_key_set' => true,   // tidak perlu key
                    'available'   => true,
                ],
            ],
            'ytdlp' => [
                'available' => $ytdlpOk,
                'version'   => $ytdlpVersion,
                'path'      => $ytdlpPath,
            ],
            'timestamp' => now()->toIso8601String(),
        ]);
    }
}
