<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\MusicOrchestratorService;
use App\Services\Providers\AudiusProvider;
use App\Services\Providers\ItunesProvider;
use App\Services\Providers\JamendoProvider;
use App\Services\Providers\YouTubeProvider;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

use App\Services\Providers\SoundCloudProvider;

class SearchController extends Controller
{
    private MusicOrchestratorService $orchestrator;

    public function __construct()
    {
        // Semua provider aktif
        $this->orchestrator = new MusicOrchestratorService([
            new YouTubeProvider(),
            new SoundCloudProvider(),
            new AudiusProvider(),
            new JamendoProvider(),
            new ItunesProvider(),
        ]);
    }

    public function __invoke(Request $request): JsonResponse
    {
        // Validasi input
        $validated = $request->validate([
            'q'         => ['required', 'string', 'min:1', 'max:200'],
            'providers' => ['nullable', 'string'],   // "youtube,audius,jamendo"
            'limit'     => ['nullable', 'integer', 'min:1', 'max:50'],
            'page'      => ['nullable', 'integer', 'min:1'],
        ]);

        $query     = trim($validated['q']);
        $limit     = (int) ($validated['limit'] ?? 50);
        $page      = (int) ($validated['page'] ?? 1);

        // Parse providers yang dipilih user (opsional)
        $selectedProviders = [];
        if (!empty($validated['providers'])) {
            $selectedProviders = array_map(
                'trim',
                explode(',', $validated['providers'])
            );
        }

        // Cache key unik berdasarkan query, providers, dan limit/page
        $cacheKey = 'search_' . md5($query . json_encode($selectedProviders) . $limit . $page);

        // Coba ambil dari cache dulu
        $searchResult = Cache::get($cacheKey);
        
        if (!$searchResult) {
            $data = $this->orchestrator->search($query, $selectedProviders, $limit);
            
            // Konversi DTO ke array SEBELUM masuk ke Cache untuk mencegah __PHP_Incomplete_Class
            $data['results'] = array_map(
                fn($track) => $track->toArray(),
                $data['results']
            );
            
            $searchResult = $data;
            
            // Hanya cache jika ada hasil — hindari menyimpan hasil kosong ke cache
            if (!empty($searchResult['results'])) {
                Cache::put($cacheKey, $searchResult, 259200); // 3 hari
            }
        }

        // Karena yang di-cache sudah array murni, kita langsung pakai hasilnya
        $tracks = $searchResult['results'];

        return response()->json([
            'query'              => $query,
            'results'            => $tracks,
            'total'              => count($tracks),
            'page'               => $page,
            'limit'              => $limit,
            'providers_queried'  => $searchResult['providers_queried'],
            'providers_failed'   => $searchResult['providers_failed'],
            'providers_skipped'  => $searchResult['providers_skipped'],
            'cached'             => false,
        ]);
    }
}
