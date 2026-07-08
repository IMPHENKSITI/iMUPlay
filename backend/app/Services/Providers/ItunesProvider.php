<?php

namespace App\Services\Providers;

use App\DTOs\UnifiedTrackDTO;
use App\Services\Providers\Contracts\MusicProviderInterface;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class ItunesProvider implements MusicProviderInterface
{
    private string $baseUrl;
    private string $country;

    public function __construct()
    {
        $this->baseUrl = config('services.itunes.base_url', 'https://itunes.apple.com');
        $this->country = config('services.itunes.country', 'ID');
    }

    public function getName(): string
    {
        return 'itunes';
    }

    public function isAvailable(): bool
    {
        return true; // iTunes tidak butuh API key
    }

    /**
     * @return UnifiedTrackDTO[]
     */
    public function search(string $query, int $limit = 10): array
    {
        try {
            $response = Http::timeout(10)->get("{$this->baseUrl}/search", [
                'term'       => $query,
                'media'      => 'music',
                'entity'     => 'song',
                'country'    => $this->country,
                'limit'      => $limit,
                'lang'       => 'en_us',
            ]);

            if (!$response->successful()) {
                Log::error('[ItunesProvider] Search failed', [
                    'status' => $response->status(),
                ]);
                return [];
            }

            $results = $response->json('results', []);

            return array_filter(
                array_map(fn($item) => $this->mapToDTO($item), $results),
                fn($dto) => $dto !== null
            );

        } catch (\Throwable $e) {
            Log::error('[ItunesProvider] Exception during search', [
                'message' => $e->getMessage(),
                'query'   => $query,
            ]);
            return [];
        }
    }

    private function mapToDTO(array $item): ?UnifiedTrackDTO
    {
        // Pastikan ini track (bukan album/artist)
        if (($item['wrapperType'] ?? '') !== 'track') return null;
        if (($item['kind'] ?? '') !== 'song') return null;

        $trackId = $item['trackId'] ?? null;
        if (!$trackId) return null;

        // iTunes kasih preview 30 detik — kita pakai sebagai stream reference
        $previewUrl = $item['previewUrl'] ?? null;

        // Upgrade thumbnail ke resolusi tinggi yang seimbang (1500x1500)
        // Menghindari ukuran file yang terlalu raksasa (seperti 3000x3000) agar tidak boros RAM/kuota
        $thumbnail = isset($item['artworkUrl100'])
            ? str_replace('100x100bb', '1500x1500bb', $item['artworkUrl100'])
            : null;

        // Bypass proxy: iTunes CDN (Apple) sangat cepat dan tidak memblokir akses langsung.
        // Biarkan Flutter mengunduhnya secara paralel untuk mencegah antrean (bottleneck) di server PHP lokal.
        $proxiedThumbnail = $thumbnail;

        return new UnifiedTrackDTO(
            id:               Str::uuid()->toString(),
            title:            $item['trackName'] ?? 'Unknown Title',
            artist:           $item['artistName'] ?? 'Unknown Artist',
            album:            $item['collectionName'] ?? null,
            thumbnail:        $proxiedThumbnail,
            source:           'itunes',
            streamReference:  ($item['artistName'] ?? '') . ' - ' . ($item['trackName'] ?? '') . ' audio',
            streamMechanism:  'ytdlp',
            duration:         (int) (($item['trackTimeMillis'] ?? 0) / 1000),
            isStreamable:     $previewUrl !== null,
            providerMetadata: [
                'itunes_id'       => $trackId,
                'genre'           => $item['primaryGenreName'] ?? null,
                'release_date'    => $item['releaseDate'] ?? null,
                'track_number'    => $item['trackNumber'] ?? null,
                'preview_url'     => $previewUrl,
                'itunes_url'      => $item['trackViewUrl'] ?? null,
            ],
        );
    }
}
