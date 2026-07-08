<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class ThumbnailProxyController extends Controller
{
    // Allowed domain whitelist — cegah SSRF attack
    private array $allowedDomains = [
        'i.ytimg.com',          // YouTube thumbnails
        'img.youtube.com',
        'i9.ytimg.com',
        'lh3.googleusercontent.com',
        'usercontent.jamendo.com',  // Jamendo artwork
        'usercontent.jamendo.com',
        'audius-content',           // Audius CDN (partial match)
        'theblueprint.xyz',         // Audius CDN
        'creatornode.audius.co',
        'blockdaemon-audius-content-node.imgix.net',
        'mzstatic.com',             // Apple/iTunes CDN
        'sndcdn.com',               // SoundCloud CDN
    ];

    public function __invoke(Request $request): Response
    {
        $url = $request->query('url');

        if (empty($url)) {
            return response('Missing url parameter', 400);
        }

        // Decode URL kalau masih encoded
        $url = urldecode($url);

        // Validasi URL format
        if (!filter_var($url, FILTER_VALIDATE_URL)) {
            return response('Invalid URL', 400);
        }

        // Cek domain whitelist — security check
        $host = parse_url($url, PHP_URL_HOST);
        if (!$this->isAllowedDomain($host)) {
            Log::warning('[ThumbnailProxy] Blocked request to non-whitelisted domain', [
                'host' => $host,
                'url'  => $url,
            ]);
            return response('Domain not allowed', 403);
        }

        try {
            // Forward User-Agent dari client asli (Flutter/browser)
            // supaya CDN tidak menganggap request ini mencurigakan
            $userAgent = $request->userAgent()
                ?? 'MusicPlayerOrchestrator/1.0';

            $response = Http::timeout(8)
                ->withHeaders([
                    'User-Agent' => $userAgent,
                    'Accept'     => 'image/*',
                ])
                ->get($url);

            // Auto-fallback untuk YouTube: Jika maxresdefault (HD) tidak ada, coba resolusi lain secara bertahap
            if (!$response->successful() && str_contains($url, 'maxresdefault.jpg')) {
                // Coba sddefault.jpg (640x480)
                $fallbackUrl1 = str_replace('maxresdefault.jpg', 'sddefault.jpg', $url);
                $response = Http::timeout(8)
                    ->withHeaders([
                        'User-Agent' => $userAgent,
                        'Accept'     => 'image/*',
                    ])
                    ->get($fallbackUrl1);
                    
                if (!$response->successful()) {
                    // Coba hqdefault.jpg (480x360) sebagai upaya terakhir
                    $fallbackUrl2 = str_replace('maxresdefault.jpg', 'hqdefault.jpg', $url);
                    $response = Http::timeout(8)
                        ->withHeaders([
                            'User-Agent' => $userAgent,
                            'Accept'     => 'image/*',
                        ])
                        ->get($fallbackUrl2);
                }
            }

            if (!$response->successful()) {
                return response('Failed to fetch thumbnail', 502);
            }

            $contentType = $response->header('Content-Type') ?? 'image/jpeg';

            // Pastikan ini benar-benar image
            if (!str_starts_with($contentType, 'image/')) {
                return response('Not an image', 403);
            }

            return response($response->body(), 200, [
                'Content-Type'  => $contentType,
                'Cache-Control' => 'public, max-age=86400', // cache 1 hari di browser
                'X-Proxied-By'  => 'MusicPlayerOrchestrator',
            ]);

        } catch (\Throwable $e) {
            Log::error('[ThumbnailProxy] Failed to proxy thumbnail', [
                'url'     => $url,
                'message' => $e->getMessage(),
            ]);
            return response('Proxy error', 500);
        }
    }

    private function isAllowedDomain(string $host): bool
    {
        foreach ($this->allowedDomains as $allowed) {
            if ($host === $allowed || str_contains($host, $allowed)) {
                return true;
            }
        }
        return false;
    }
}
