<?php

namespace App\Services;

use App\Services\MusicOrchestratorService;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ArtistProfileService
{
    private MusicOrchestratorService $orchestrator;
    private string $itunesBaseUrl;
    private string $country;

    public function __construct()
    {
        $this->orchestrator = new MusicOrchestratorService([
            new \App\Services\Providers\YouTubeProvider(),
            new \App\Services\Providers\AudiusProvider(),
            new \App\Services\Providers\JamendoProvider(),
            new \App\Services\Providers\ItunesProvider(),
        ]);
        $this->itunesBaseUrl = config('services.itunes.base_url', 'https://itunes.apple.com');
        $this->country = config('services.itunes.country', 'ID');
    }

    public function getProfile(string $artistName): array
    {
        // 1. Dapatkan artist metadata dan albums dari iTunes
        $itunesData = $this->fetchItunesArtistData($artistName);

        // 2. Dapatkan Top Tracks lintas platform, hanya lagu milik artis ini
        $searchData = $this->orchestrator->search($artistName, [], 50);
        $artistNameLower = strtolower($artistName);
        $topTracks = array_values(array_filter(
            array_map(
                fn($track) => $track->toArray(),
                $searchData['results']
            ),
            function ($track) use ($artistNameLower) {
                $trackArtistLower = strtolower($track['artist'] ?? '');
                // Cocokkan jika nama artis mengandung kata kunci pencarian atau sebaliknya
                return str_contains($trackArtistLower, $artistNameLower)
                    || str_contains($artistNameLower, $trackArtistLower);
            }
        ));

        // Batasi maks 30 lagu teratas
        $topTracks = array_slice($topTracks, 0, 30);

        return [
            'artist'     => $itunesData['artist'],
            'top_tracks' => $topTracks,
            'albums'     => $itunesData['albums'],
            'singles'    => $itunesData['singles'],
        ];
    }

    private function fetchItunesArtistData(string $artistName): array
    {
        $result = [
            'artist' => [
                'name'    => $artistName,
                'artwork' => null,
                'genre'   => null,
            ],
            'related_artists' => [],
            'albums'  => [],
            'singles' => [],
        ];

        try {
            $countriesToTry = array_unique([
                $this->country, 'US', 'ID', 'JP', 'KR', 'GB', 'CN', 'RU', 'TW', 'HK', 
                'ES', 'MX', 'BR', 'IN', 'TH', 'AE', 'DE', 'FR', 'MY', 'PH', 'VN', 'TR'
            ]);

            $artistId = null;
            $allArtistResults = [];

            // 1. Cari exact musicArtist berdasarkan nama, kumpulkan dari semua negara
            foreach ($countriesToTry as $c) {
                try {
                    $artistResponse = Http::timeout(5)->get("{$this->itunesBaseUrl}/search", [
                        'term'    => $artistName,
                        'entity'  => 'musicArtist',
                        'limit'   => 15,
                        'country' => $c,
                    ]);

                    if ($artistResponse->successful()) {
                        $artistData = $artistResponse->json();
                        if (!empty($artistData['results'])) {
                            foreach ($artistData['results'] as $a) {
                                $aId = $a['artistId'] ?? null;
                                if ($aId && !isset($allArtistResults[$aId])) {
                                    $allArtistResults[$aId] = $a;
                                }
                            }
                        }
                    }
                } catch (\Throwable $e) {
                    continue; // Abaikan error timeout/network, lanjut ke negara berikutnya
                }
                
                // Jika sudah ketemu setidaknya satu, kita bisa hentikan pencarian artis
                if (!empty($allArtistResults)) {
                    break;
                }
            }

            if (empty($allArtistResults)) {
                return $result;
            }

            // Tentukan Main Artist dan Related Artists
            $mainArtist = null;
            $relatedArtists = [];

            foreach ($allArtistResults as $id => $a) {
                if ($mainArtist === null && strtolower($a['artistName'] ?? '') === strtolower($artistName)) {
                    $mainArtist = $a;
                    $artistId = $id;
                } else {
                    $relatedArtists[] = [
                        'name'  => $a['artistName'] ?? 'Unknown',
                        'genre' => $a['primaryGenreName'] ?? null,
                    ];
                }
            }

            // Jika tidak ada exact match, pakai yang pertama kali ditemukan
            if (!$mainArtist) {
                $mainArtist = reset($allArtistResults);
                $artistId = $mainArtist['artistId'];
                // Buang mainArtist dari related
                array_shift($relatedArtists);
            }

            $result['artist']['name'] = $mainArtist['artistName'];
            $result['artist']['genre'] = $mainArtist['primaryGenreName'] ?? null;
            $result['related_artists'] = array_slice($relatedArtists, 0, 10); // Ambil maks 10 related artists

            // 2. Lookup album khusus untuk artistId tersebut dari SEMUA NEGARA agar komplit
            $collectedAlbums = [];
            foreach ($countriesToTry as $c) {
                try {
                    $albumResponse = Http::timeout(5)->get("{$this->itunesBaseUrl}/lookup", [
                        'id'      => $artistId,
                        'entity'  => 'album',
                        'limit'   => 200,
                        'country' => $c,
                    ]);

                    if ($albumResponse->successful()) {
                        $albumData = $albumResponse->json();
                        $results = $albumData['results'] ?? [];

                        foreach ($results as $item) {
                            if (($item['wrapperType'] ?? '') === 'artist') continue;
                            
                            $colId = $item['collectionId'] ?? null;
                            if ($colId && !isset($collectedAlbums[$colId])) {
                                $collectedAlbums[$colId] = $item;
                            }
                        }
                    }
                } catch (\Throwable $e) {
                    continue; // Abaikan error timeout/network, lanjut ke negara berikutnya
                }
            }

            foreach ($collectedAlbums as $item) {
                $artwork = isset($item['artworkUrl100'])
                    ? str_replace('100x100bb', '1000x1000bb', $item['artworkUrl100'])
                    : null;

                // Bypass proxy: Biarkan Flutter unduh langsung dari CDN Apple
                $proxiedArtwork = $artwork;

                // Gunakan artwork album pertama sebagai artwork artist
                if ($result['artist']['artwork'] === null && $proxiedArtwork) {
                    $result['artist']['artwork'] = $proxiedArtwork;
                }

                $trackCount = $item['trackCount'] ?? 0;
                $type = $trackCount > 3 ? 'album' : 'single';
                $releaseYear = isset($item['releaseDate']) ? substr($item['releaseDate'], 0, 4) : '';

                $albumDto = [
                    'id'           => (string) ($item['collectionId'] ?? ''),
                    'title'        => $item['collectionName'] ?? 'Unknown',
                    'thumbnail'    => $proxiedArtwork,
                    'year'         => $releaseYear,
                    'track_count'  => $trackCount,
                    'type'         => $type,
                    'genre'        => $item['primaryGenreName'] ?? null,
                ];

                if ($type === 'album') {
                    $result['albums'][] = $albumDto;
                } else {
                    $result['singles'][] = $albumDto;
                }
            }

            return $result;
        } catch (\Throwable $e) {
            Log::error('[ArtistProfileService] Failed to fetch iTunes data', [
                'artist' => $artistName,
                'error'  => $e->getMessage()
            ]);
            return $result;
        }
    }
}
