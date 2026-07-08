<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\ArtistProfileService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;

class ArtistController extends Controller
{
    private ArtistProfileService $artistService;

    public function __construct(ArtistProfileService $artistService)
    {
        $this->artistService = $artistService;
    }

    public function show(string $name, Request $request): JsonResponse
    {
        $name = urldecode($name);
        
        if (empty($name)) {
            return response()->json(['error' => 'Artist name is required'], 400);
        }

        // Cache hasil profile artist selama 24 jam (86400 detik)
        // Kunci cache mengikuti format standard sesuai rules AGENTS.md
        $cacheKey = "artist_profile_" . md5(strtolower($name));

        $data = Cache::get($cacheKey);
        if (!$data || empty($data['top_tracks']) && empty($data['albums']) && empty($data['singles'])) {
            $data = $this->artistService->getProfile($name);
            // Hanya cache jika berhasil mendapatkan data
            if (!empty($data['top_tracks']) || !empty($data['albums']) || !empty($data['singles'])) {
                Cache::put($cacheKey, $data, 86400);
            }
        }

        return response()->json([
            'status' => 200,
            'data'   => $data
        ]);
    }
}
