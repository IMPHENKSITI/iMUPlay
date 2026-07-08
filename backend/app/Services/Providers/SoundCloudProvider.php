<?php

namespace App\Services\Providers;

use App\DTOs\UnifiedTrackDTO;
use App\Services\Providers\Contracts\MusicProviderInterface;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class SoundCloudProvider implements MusicProviderInterface
{
    public function getName(): string
    {
        return 'soundcloud';
    }

    public function isAvailable(): bool
    {
        return true; 
    }

    /**
     * Cari lagu di SoundCloud menggunakan yt-dlp scsearch
     * @return UnifiedTrackDTO[]
     */
    public function search(string $query, int $limit = 10): array
    {
        if (!$this->isAvailable()) {
            return [];
        }

        try {
            $escapedQuery = escapeshellarg("scsearch{$limit}:{$query}");
            
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

                $results[] = $this->mapToDTO($item);
            }

            return $results;

        } catch (\Throwable $e) {
            Log::error('[SoundCloudProvider] Exception during search', [
                'message' => $e->getMessage(),
                'query'   => $query,
            ]);
            return [];
        }
    }

    private function mapToDTO(array $item): UnifiedTrackDTO
    {
        $rawTitle = $item['title'] ?? 'Unknown Title';
        $uploader = $item['uploader'] ?? '';
        
        [$artist, $title] = $this->parseArtistTitle($rawTitle, $uploader);

        $thumbnailUrl = null;
        if (!empty($item['thumbnails'])) {
            $lastThumb = end($item['thumbnails']);
            $thumbnailUrl = $lastThumb['url'] ?? null;
        }

        $url = $item['webpage_url'] ?? $item['url'] ?? '';
        
        $proxiedThumbnail = $thumbnailUrl; // Bypass proxy for performance

        return new UnifiedTrackDTO(
            id:               Str::uuid()->toString(),
            title:            $title,
            artist:           $artist,
            album:            null,
            thumbnail:        $proxiedThumbnail,
            source:           'soundcloud',
            streamReference:  $url,
            streamMechanism:  'ytdlp',
            duration:         isset($item['duration']) ? (int) $item['duration'] : 0,
            isStreamable:     true,
            providerMetadata: [
                'raw_url'       => $url,
                'uploader'      => $uploader,
                'raw_title'     => $rawTitle,
            ],
        );
    }

    private function parseArtistTitle(string $rawTitle, string $uploader): array
    {
        $cleaned = trim($rawTitle);

        if (str_contains($cleaned, ' - ')) {
            $parts = explode(' - ', $cleaned, 2);
            return [trim($parts[0]), trim($parts[1])];
        }

        return [$uploader ?: 'Unknown Artist', $cleaned];
    }
}
