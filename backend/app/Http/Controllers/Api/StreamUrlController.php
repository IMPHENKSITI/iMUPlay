<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\YtDlpService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class StreamUrlController extends Controller
{
    public function __construct(private YtDlpService $ytDlp) {}

    public function __invoke(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'source'    => ['required', 'string', 'in:youtube,audius,jamendo,itunes,soundcloud'],
            'reference' => ['required', 'string', 'min:1', 'max:500'],
            'stream_mechanism' => ['nullable', 'string'],
            'duration'  => ['nullable', 'integer', 'min:1'],
        ]);

        $source    = $validated['source'];
        $reference = $validated['reference'];
        $duration  = $validated['duration'] ?? null;
        
        // Cache key unik
        $cacheKey = "stream_url_{$source}_" . md5($reference);

        // Coba ambil dari cache dulu
        if (Cache::has($cacheKey)) {
            $result = Cache::get($cacheKey);
            return response()->json($result['data'], $result['status']);
        }

        $result = match($source) {
            'youtube'    => $this->resolveYoutube($reference),
            'audius'     => $this->resolveAudius($reference),
            'jamendo'    => $this->resolveJamendo($reference),
            'itunes'     => $this->resolveYoutubeSearch($reference, $duration),
            'soundcloud' => $this->resolveSoundCloud($reference),
        };

        // Jangan cache jika statusnya error (misal 404, 422, 500)
        if (isset($result['status']) && $result['status'] === 200) {
            // YouTube stream URLs biasanya expired dalam 4-6 jam dari Google.
            // Kita cache maksimal 2 jam (7200 detik) saja untuk youtube & itunes (yang pakai youtube)
            // Untuk sumber lain (Jamendo, Audius, SoundCloud), aman di-cache 6 jam (21600 detik).
            $ttl = in_array($source, ['youtube', 'itunes']) ? 7200 : 21600;
            Cache::put($cacheKey, $result, $ttl);
        }

        return response()->json($result['data'], $result['status']);
    }

    /**
     * Cari lagu di YouTube (fallback untuk iTunes)
     */
    private function resolveYoutubeSearch(string $query, ?int $duration = null): array
    {
        // Bersihkan query dari tambahan seperti " audio" yang merusak algoritma pencarian YouTube
        $cleanQuery = trim(str_ireplace(' audio', '', $query));
        
        // 1. Coba gunakan YouTube API terlebih dahulu untuk mencari Video ID resmi
        try {
            $youtubeProvider = app(\App\Services\Providers\YouTubeProvider::class);
            
            // Jika ada durasi, ambil 5 hasil untuk dicari yang durasinya paling pas. Jika tidak, cukup 1.
            $limit = $duration ? 5 : 1;
            $results = $youtubeProvider->searchViaApi($cleanQuery, $limit);
            
            if (!empty($results)) {
                $bestVideoId = $results[0]->streamReference;
                
                // Cari video yang durasinya paling mendekati lagu aslinya di iTunes (selisih terkecil)
                if ($duration && count($results) > 1) {
                    $closestDiff = PHP_INT_MAX;
                    foreach ($results as $r) {
                        $diff = abs($r->duration - $duration);
                        // Toleransi: kita lebih menyukai durasi yang presisi
                        if ($diff < $closestDiff) {
                            $closestDiff = $diff;
                            $bestVideoId = $r->streamReference;
                        }
                    }
                }
                
                \Illuminate\Support\Facades\Log::info('[StreamUrlController] Selected video for iTunes: ', ['query' => $query, 'target_duration' => $duration, 'selected_video' => $bestVideoId]);
                
                return $this->resolveYoutube($bestVideoId); // Lanjutkan dengan video ID terbaik
            }
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('[StreamUrlController] YouTube API search failed, falling back to yt-dlp backdoor.', ['error' => $e->getMessage()]);
        }

        // 2. Fallback: yt-dlp backdoor search jika API habis/gagal
        if (!$this->ytDlp->isAvailable()) {
            return [
                'status' => 503,
                'data' => [
                    'stream_url' => null,
                    'error'      => 'YTDLP_NOT_FOUND',
                    'message'    => 'yt-dlp is not installed or not in PATH',
                ]
            ];
        }

        $result = $this->ytDlp->resolveBySearch($query);

        if ($result['error']) {
            return [
                'status' => 422,
                'data' => [
                    'stream_url' => null,
                    'error'      => $result['error'],
                    'message'    => 'Failed to resolve stream URL from YouTube search',
                ]
            ];
        }

        return [
            'status' => 200,
            'data' => [
                'stream_url' => $result['stream_url'],
                'format'     => $result['format'],
                'source'     => 'youtube_search',
                'reference'  => $query,
                'expires_in' => 21600, // ~6 jam (YouTube URL expiry)
                'error'      => null,
            ]
        ];
    }

    /**
     * YouTube: jalankan yt-dlp untuk dapat audio stream URL
     */
    private function resolveYoutube(string $videoId): array
    {
        if (!$this->ytDlp->isAvailable()) {
            return [
                'status' => 503,
                'data' => [
                    'stream_url' => null,
                    'error'      => 'YTDLP_NOT_FOUND',
                    'message'    => 'yt-dlp is not installed or not in PATH',
                ]
            ];
        }

        $result = $this->ytDlp->resolveStreamUrl($videoId);

        if ($result['error']) {
            return [
                'status' => 422,
                'data' => [
                    'stream_url' => null,
                    'error'      => $result['error'],
                    'message'    => 'Failed to resolve stream URL from YouTube',
                ]
            ];
        }

        return [
            'status' => 200,
            'data' => [
                'stream_url' => $result['stream_url'],
                'format'     => $result['format'],
                'source'     => 'youtube',
                'reference'  => $videoId,
                'expires_in' => 21600,
                'error'      => null,
            ]
        ];
    }

    /**
     * Audius: stream URL langsung dari API (tidak butuh yt-dlp)
     */
    private function resolveAudius(string $trackId): array
    {
        $baseUrl   = config('services.audius.base_url', 'https://api.audius.co/v1');
        $appName   = config('services.audius.app_name', 'MusicPlayerOrchestrator');
        $streamUrl = "{$baseUrl}/tracks/{$trackId}/stream?app_name={$appName}";

        return [
            'status' => 200,
            'data' => [
                'stream_url' => $streamUrl,
                'format'     => 'mp3',
                'source'     => 'audius',
                'reference'  => $trackId,
                'expires_in' => null, // Audius URL tidak expired
                'error'      => null,
            ]
        ];
    }

    /**
     * Jamendo: stream URL dari field `audio` di response (direct MP3)
     */
    private function resolveJamendo(string $directUrl): array
    {
        return [
            'status' => 200,
            'data' => [
                'stream_url' => $directUrl,
                'format'     => 'mp3',
                'source'     => 'jamendo',
                'reference'  => $directUrl,
                'expires_in' => null, // Jamendo URL tidak expired
                'error'      => null,
            ]
        ];
    }

    /**
     * SoundCloud: jalankan yt-dlp untuk dapat audio stream URL
     */
    private function resolveSoundCloud(string $url): array
    {
        if (!$this->ytDlp->isAvailable()) {
            return [
                'status' => 503,
                'data' => [
                    'stream_url' => null,
                    'error'      => 'YTDLP_NOT_FOUND',
                    'message'    => 'yt-dlp is not installed or not in PATH',
                ]
            ];
        }

        $result = $this->ytDlp->resolveDirectUrl($url);

        if ($result['error']) {
            return [
                'status' => 422,
                'data' => [
                    'stream_url' => null,
                    'error'      => $result['error'],
                    'message'    => 'Failed to resolve stream URL from SoundCloud',
                ]
            ];
        }

        return [
            'status' => 200,
            'data' => [
                'stream_url' => $result['stream_url'],
                'format'     => $result['format'],
                'source'     => 'soundcloud',
                'reference'  => $url,
                'expires_in' => 21600, // ~6 jam
                'error'      => null,
            ]
        ];
    }
}
