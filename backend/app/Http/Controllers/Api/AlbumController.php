<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class AlbumController extends Controller
{
    public function show(string $id): JsonResponse
    {
        if (empty($id)) {
            return response()->json(['error' => 'Album ID is required'], 400);
        }

        $cacheKey = "album_details_" . md5($id);

        $data = Cache::get($cacheKey);
        if (!$data || empty($data['tracks'])) {
            $data = $this->fetchItunesAlbumTracks($id);
            // Hanya cache jika berhasil mendapatkan data (mencegah cache kosong selamanya)
            if (!empty($data['tracks'])) {
                Cache::put($cacheKey, $data, 86400);
            }
        }

        return response()->json([
            'status' => 200,
            'data'   => $data
        ]);
    }

    private function fetchItunesAlbumTracks(string $id): array
    {
        $baseUrl = config('services.itunes.base_url', 'https://itunes.apple.com');
        $country = config('services.itunes.country', 'ID');

        $result = [
            'album'  => null,
            'tracks' => [],
        ];

        try {
            // Daftar 20+ negara utama untuk memastikan album ketemu di belahan dunia manapun
            $countriesToTry = array_unique([
                $country, 'US', 'ID', 'JP', 'KR', 'GB', 'CN', 'RU', 'TW', 'HK', 
                'ES', 'MX', 'BR', 'IN', 'TH', 'AE', 'DE', 'FR', 'MY', 'PH', 'VN', 'TR'
            ]);
            $results = [];

            foreach ($countriesToTry as $c) {
                try {
                    $response = Http::timeout(5)->get("{$baseUrl}/lookup", [
                        'id'      => $id,
                        'entity'  => 'song',
                        'country' => $c,
                        'lang'    => 'en_us',
                    ]);

                    if ($response->successful()) {
                        $data = $response->json();
                        if (!empty($data['results'])) {
                            $results = $data['results'];
                            break;
                        }
                    }
                } catch (\Throwable $e) {
                    // Abaikan error (misal timeout) pada negara ini, lanjut ke negara berikutnya
                    continue;
                }
            }

            if (empty($results)) {
                return $result;
            }

            foreach ($results as $item) {
                if (($item['wrapperType'] ?? '') === 'collection' || ($item['collectionType'] ?? '') === 'Album') {
                    // Album metadata
                    $artwork = isset($item['artworkUrl100'])
                        ? str_replace('100x100bb', '1000x1000bb', $item['artworkUrl100'])
                        : null;

                    $result['album'] = [
                        'id'          => (string) $item['collectionId'],
                        'title'       => $item['collectionName'] ?? 'Unknown Album',
                        'artist'      => $item['artistName'] ?? 'Unknown Artist',
                        'thumbnail'   => $artwork,
                        'year'        => isset($item['releaseDate']) ? substr($item['releaseDate'], 0, 4) : '',
                        'track_count' => $item['trackCount'] ?? 0,
                        'genre'       => $item['primaryGenreName'] ?? null,
                    ];
                } elseif (($item['wrapperType'] ?? '') === 'track' && ($item['kind'] ?? '') === 'song') {
                    // Track metadata mapped to OnlineSongModel format
                    $artwork = isset($item['artworkUrl100'])
                        ? str_replace('100x100bb', '1000x1000bb', $item['artworkUrl100'])
                        : null;

                    // Stream Reference is the title + artist for yt-dlp search fallback
                    $artist = $item['artistName'] ?? 'Unknown';
                    $title  = $item['trackName'] ?? 'Unknown';
                    $searchQuery = "{$artist} - {$title}";

                    $result['tracks'][] = [
                        'id'               => (string) $item['trackId'],
                        'title'            => $title,
                        'artist'           => $artist,
                        'album'            => $item['collectionName'] ?? 'Unknown Album',
                        'thumbnail'        => $artwork,
                        'duration'         => isset($item['trackTimeMillis']) ? (int) floor($item['trackTimeMillis'] / 1000) : 0,
                        'source'           => 'itunes',
                        'stream_reference' => $searchQuery,
                        'stream_mechanism' => 'redirect',
                        'is_streamable'    => true,
                    ];
                }
            }

            return $result;

        } catch (\Throwable $e) {
            return $result;
        }
    }
}
