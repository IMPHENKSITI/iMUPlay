<?php

namespace App\Services\Providers;

use App\DTOs\UnifiedTrackDTO;
use App\Services\Providers\Contracts\MusicProviderInterface;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class JamendoProvider implements MusicProviderInterface
{
    private string $baseUrl;
    private string $clientId;

    public function __construct()
    {
        $this->baseUrl  = config('services.jamendo.base_url', 'https://api.jamendo.com/v3.0');
        $this->clientId = config('services.jamendo.client_id', '709fa152');
    }

    public function getName(): string
    {
        return 'jamendo';
    }

    public function isAvailable(): bool
    {
        return !empty($this->clientId);
    }

    /**
     * @return UnifiedTrackDTO[]
     */
    public function search(string $query, int $limit = 10): array
    {
        try {
            $response = Http::timeout(10)->get("{$this->baseUrl}/tracks/", [
                'client_id'   => $this->clientId,
                'format'      => 'json',
                'namesearch'  => $query,   // namesearch = cari di title/artist
                'limit'       => $limit,
                'order'       => 'relevance',
                // audiodownload field selalu ada, audio stream butuh tambahan param
            ]);

            if (!$response->successful()) {
                Log::error('[JamendoProvider] Search failed', [
                    'status' => $response->status(),
                    'body'   => $response->body(),
                ]);
                return [];
            }

            $results = $response->json('results', []);

            $dtos = [];
            foreach ($results as $track) {
                $dto = $this->mapToDTO($track);
                if ($dto !== null) {
                    $dtos[] = $dto;
                }
            }

            return $dtos;

        } catch (\Throwable $e) {
            Log::error('[JamendoProvider] Exception during search', [
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

        // Coba ambil stream URL dari berbagai field yang mungkin ada
        // Jamendo punya beberapa field tergantung parameter yang dipakai
        $audioUrl = $track['audio']             // streaming URL (butuh param khusus)
            ?? $track['audiodownload']          // download URL (selalu ada)
            ?? $track['audiodownload_allowed']  // fallback
            ?? null;

        // Kalau tidak ada URL audio sama sekali, skip track ini
        if (empty($audioUrl) || $audioUrl === 'false' || $audioUrl === false) {
            Log::debug('[JamendoProvider] Track skipped — no audio URL', ['id' => $id, 'name' => $track['name'] ?? '']);
            return null;
        }

        // Proxy thumbnail
        $thumbnail = $track['image'] ?? $track['album_image'] ?? null;
        $proxiedThumbnail = $thumbnail; // Bypass proxy for performance

        return new UnifiedTrackDTO(
            id:               Str::uuid()->toString(),
            title:            $track['name'] ?? 'Unknown Title',
            artist:           $track['artist_name'] ?? 'Unknown Artist',
            album:            $track['album_name'] ?? null,
            thumbnail:        $proxiedThumbnail,
            source:           'jamendo',
            streamReference:  $audioUrl,
            streamMechanism:  'direct_url',
            duration:         (int) ($track['duration'] ?? 0),
            isStreamable:     true,
            providerMetadata: [
                'jamendo_id' => $id,
                'license'    => $track['license_ccurl'] ?? null,
                'album_id'   => $track['album_id'] ?? null,
                'shareurl'   => $track['shareurl'] ?? null,
            ],
        );
    }
}
