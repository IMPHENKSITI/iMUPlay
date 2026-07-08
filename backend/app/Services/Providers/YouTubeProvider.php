<?php

namespace App\Services\Providers;

use App\DTOs\UnifiedTrackDTO;
use App\Services\Providers\Contracts\MusicProviderInterface;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class YouTubeProvider implements MusicProviderInterface
{
    private string $apiKey;
    private string $baseUrl;

    public function __construct()
    {
        $this->apiKey  = config('services.youtube.api_key', '');
        $this->baseUrl = config('services.youtube.base_url', 'https://www.googleapis.com/youtube/v3');
    }

    public function getName(): string
    {
        return 'youtube';
    }

    public function isAvailable(): bool
    {
        return true; 
    }

    /**
     * Cari lagu di YouTube (Hybrid: API first, yt-dlp fallback)
     * @return UnifiedTrackDTO[]
     */
    public function search(string $query, int $limit = 10): array
    {
        // 1. Prioritaskan YouTube Data API sesuai permintaan user
        $results = $this->searchViaApi($query, $limit);
        
        if (!empty($results)) {
            return $results;
        }

        // 2. Jika API gagal (karena limit harian habis), fallback ke yt-dlp otomatis
        Log::warning('[YouTubeProvider] Data API search failed or empty, falling back to yt-dlp.');
        return $this->searchViaYtdlp($query, $limit);
    }

    private function searchViaYtdlp(string $query, int $limit): array
    {
        try {
            $escapedQuery = escapeshellarg("ytsearch{$limit}:{$query}");
            $command = "yt-dlp {$escapedQuery} --dump-json --flat-playlist 2>&1";
            
            $output = shell_exec($command);
            
            if (!$output) {
                return [];
            }

            $lines = explode("\n", trim($output));
            $results = [];

            foreach ($lines as $line) {
                if (empty(trim($line))) continue;
                
                $item = json_decode($line, true);
                if (!$item || (isset($item['_type']) && $item['_type'] !== 'url')) {
                    if (!isset($item['id']) || !isset($item['title'])) {
                        continue;
                    }
                }

                $results[] = $this->mapYtdlpToDTO($item);
            }

            return $results;

        } catch (\Throwable $e) {
            Log::error('[YouTubeProvider] Exception during yt-dlp search', [
                'message' => $e->getMessage(),
                'query'   => $query,
            ]);
            return [];
        }
    }

    public function searchViaApi(string $query, int $limit): array
    {
        if (empty($this->apiKey) || $this->apiKey === 'PASTE_YOUTUBE_API_KEY_DISINI') {
            Log::warning('[YouTubeProvider] API key not set, skipping API fallback.');
            return [];
        }

        try {
            $response = Http::timeout(10)->get("{$this->baseUrl}/search", [
                'part'            => 'snippet',
                'q'               => $query,
                'type'            => 'video',
                'videoCategoryId' => '10', // Music category
                'maxResults'      => $limit,
                'key'             => $this->apiKey,
            ]);

            if (!$response->successful()) {
                Log::error('[YouTubeProvider] API Search failed', [
                    'status' => $response->status(),
                    'body'   => $response->body(),
                ]);
                return [];
            }

            $items = $response->json('items', []);
            if (empty($items)) {
                return [];
            }

            // Fetch durations for actual videos
            $videoIds = [];
            foreach ($items as $i) {
                if (isset($i['id']['videoId'])) {
                    $videoIds[] = $i['id']['videoId'];
                }
            }
            
            $durations = !empty($videoIds) ? $this->fetchApiDurations($videoIds) : [];

            $dtos = array_map(fn($item) => $this->mapApiToDTO($item, $durations), $items);
            return array_values(array_filter($dtos));

        } catch (\Throwable $e) {
            Log::error('[YouTubeProvider] Exception during API search', [
                'message' => $e->getMessage(),
                'query'   => $query,
            ]);
            return [];
        }
    }

    private function fetchApiDurations(array $videoIds): array
    {
        try {
            $response = Http::timeout(5)->get("{$this->baseUrl}/videos", [
                'part' => 'contentDetails',
                'id'   => implode(',', $videoIds),
                'key'  => $this->apiKey,
            ]);

            if (!$response->successful()) {
                return [];
            }

            $items = $response->json('items', []);
            $durations = [];
            
            foreach ($items as $item) {
                $id = $item['id'];
                $pt = $item['contentDetails']['duration'] ?? 'PT0S';
                $durations[$id] = $this->parsePtDuration($pt);
            }
            
            return $durations;
        } catch (\Throwable $e) {
            return [];
        }
    }

    private function parsePtDuration(string $pt): int
    {
        try {
            $interval = new \DateInterval($pt);
            return ($interval->h * 3600) + ($interval->i * 60) + $interval->s;
        } catch (\Throwable $e) {
            return 0;
        }
    }

    private function mapYtdlpToDTO(array $item): UnifiedTrackDTO
    {
        $rawTitle = $item['title'] ?? 'Unknown Title';
        $uploader = $item['uploader'] ?? $item['channel'] ?? '';
        
        [$artist, $title] = $this->parseArtistTitle($rawTitle, $uploader);

        $videoId = $item['id'];
        $url = $item['url'] ?? "https://www.youtube.com/watch?v={$videoId}";
        
        // YouTube thumbnail URLs are predictable. 
        // We now request maxresdefault.jpg (1280x720) for MAXIMUM quality.
        $thumbnailUrl = "https://i.ytimg.com/vi/{$videoId}/maxresdefault.jpg";

        return new UnifiedTrackDTO(
            id:               Str::uuid()->toString(),
            title:            $title,
            artist:           $artist,
            album:            null,
            thumbnail:        $thumbnailUrl,
            source:           'youtube',
            streamReference:  $videoId,
            streamMechanism:  'ytdlp',
            duration:         isset($item['duration']) ? (int) $item['duration'] : 0,
            isStreamable:     true,
            providerMetadata: [
                'video_id'      => $videoId,
                'channel'       => $uploader,
                'raw_title'     => $rawTitle,
            ],
        );
    }

    private function mapApiToDTO(array $item, array $durations): ?UnifiedTrackDTO
    {
        $snippet  = $item['snippet'] ?? [];
        $videoId  = $item['id']['videoId'] ?? null;
        
        // Skip jika bukan video
        if (!$videoId) {
            return null;
        }

        $duration = $durations[$videoId] ?? 0;

        $thumbnails = $snippet['thumbnails'] ?? [];
        // YouTube thumbnail URLs are predictable. 
        // We now request maxresdefault.jpg (1280x720) for MAXIMUM quality.
        $thumbnailUrl = "https://i.ytimg.com/vi/{$videoId}/maxresdefault.jpg";

        $rawTitle = $snippet['title'] ?? 'Unknown Title';
        [$artist, $title] = $this->parseArtistTitle($rawTitle, $snippet['channelTitle'] ?? '');

        return new UnifiedTrackDTO(
            id:               Str::uuid()->toString(),
            title:            $title,
            artist:           $artist,
            album:            null,
            thumbnail:        $thumbnailUrl,
            source:           'youtube',
            streamReference:  $videoId,
            streamMechanism:  'ytdlp',
            duration:         $duration,
            isStreamable:     true,
            providerMetadata: [
                'video_id'      => $videoId,
                'channel'       => $snippet['channelTitle'] ?? '',
                'raw_title'     => $rawTitle,
            ],
        );
    }

    private function parseArtistTitle(string $rawTitle, string $channelTitle): array
    {
        $cleaned = preg_replace('/\s*[\(\[][^\)\]]*[\)\]]\s*/', ' ', $rawTitle);
        $cleaned = trim($cleaned);

        if (str_contains($cleaned, ' - ')) {
            $parts = explode(' - ', $cleaned, 2);
            return [trim($parts[0]), trim($parts[1])];
        }

        return [$channelTitle ?: 'Unknown Artist', $cleaned];
    }
}
