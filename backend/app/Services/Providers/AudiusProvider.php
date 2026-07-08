<?php

namespace App\Services\Providers;

use App\DTOs\UnifiedTrackDTO;
use App\Services\Providers\Contracts\MusicProviderInterface;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class AudiusProvider implements MusicProviderInterface
{
    private string $baseUrl;
    private string $appName;

    public function __construct()
    {
        $this->baseUrl = config('services.audius.base_url', 'https://api.audius.co/v1');
        $this->appName = config('services.audius.app_name', 'MusicPlayerOrchestrator');
    }

    public function getName(): string
    {
        return 'audius';
    }

    public function isAvailable(): bool
    {
        return true; // Audius tidak butuh API key
    }

    /**
     * @return UnifiedTrackDTO[]
     */
    public function search(string $query, int $limit = 10): array
    {
        try {
            $response = Http::timeout(10)
                ->withHeaders(['X-App-Name' => $this->appName])
                ->get("{$this->baseUrl}/tracks/search", [
                    'query' => $query,
                    'limit' => $limit,
                ]);

            if (!$response->successful()) {
                Log::error('[AudiusProvider] Search failed', [
                    'status' => $response->status(),
                    'body'   => $response->body(),
                ]);
                return [];
            }

            $tracks = $response->json('data', []);

            return array_filter(
                array_map(fn($track) => $this->mapToDTO($track), $tracks),
                fn($dto) => $dto !== null
            );

        } catch (\Throwable $e) {
            Log::error('[AudiusProvider] Exception during search', [
                'message' => $e->getMessage(),
                'query'   => $query,
            ]);
            return [];
        }
    }

    private function mapToDTO(array $track): ?UnifiedTrackDTO
    {
        $id = $track['id'] ?? null;
        if (!$id) return null;

        // Ambil thumbnail terbaik
        $artwork   = $track['artwork'] ?? [];
        $thumbnail = $artwork['480x480']
            ?? $artwork['150x150']
            ?? $artwork['_480x480']
            ?? null;

        // Bypass proxy for performance
        $proxiedThumbnail = $thumbnail;

        $artist = $track['user']['name'] ?? $track['user']['handle'] ?? 'Unknown Artist';

        return new UnifiedTrackDTO(
            id:               Str::uuid()->toString(),
            title:            $track['title'] ?? 'Unknown Title',
            artist:           $artist,
            album:            null,
            thumbnail:        $proxiedThumbnail,
            source:           'audius',
            streamReference:  $id,
            streamMechanism:  'audius_api',
            duration:         (int) ($track['duration'] ?? 0),
            isStreamable:     true,
            providerMetadata: [
                'audius_id'    => $id,
                'genre'        => $track['genre'] ?? null,
                'play_count'   => $track['play_count'] ?? 0,
                'repost_count' => $track['repost_count'] ?? 0,
            ],
        );
    }
}
