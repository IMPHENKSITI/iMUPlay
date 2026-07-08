<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;

class YtDlpService
{
    private string $ytdlpPath;
    private int    $timeout;

    public function __construct()
    {
        $this->ytdlpPath = config('services.ytdlp.path', 'yt-dlp');
        $this->timeout   = config('services.ytdlp.timeout', 15);
    }

    /**
     * Dapatkan direct audio stream URL dari YouTube video ID
     *
     * @param  string $videoId  YouTube video ID (contoh: dQw4w9WgXcQ)
     * @return array{stream_url: string|null, format: string|null, error: string|null}
     */
    public function resolveStreamUrl(string $videoId): array
    {
        $videoUrl = "https://www.youtube.com/watch?v={$videoId}";

        // Format: prioritaskan m4a (compatible dengan just_audio Flutter)
        // fallback ke audio terbaik yang tersedia
        $formatSelector = 'bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio';

        $command = sprintf(
            '%s -f "%s" --get-url --no-playlist --socket-timeout %d "%s" 2>&1',
            escapeshellcmd($this->ytdlpPath),
            $formatSelector,
            $this->timeout,
            $videoUrl
        );

        Log::info('[YtDlpService] Resolving stream URL', [
            'video_id' => $videoId,
            'command'  => $command,
        ]);

        $startTime = microtime(true);
        $output    = shell_exec($command);
        $elapsed   = round(microtime(true) - $startTime, 2);

        Log::info('[YtDlpService] yt-dlp completed', [
            'elapsed_seconds' => $elapsed,
            'video_id'        => $videoId,
        ]);

        if (empty($output)) {
            Log::error('[YtDlpService] Empty output from yt-dlp', ['video_id' => $videoId]);
            return ['stream_url' => null, 'format' => null, 'error' => 'YTDLP_EMPTY_OUTPUT'];
        }

        // Ambil baris pertama yang merupakan URL valid
        $lines = array_filter(
            array_map('trim', explode("\n", trim($output))),
            fn($line) => str_starts_with($line, 'http')
        );

        if (empty($lines)) {
            Log::error('[YtDlpService] No valid URL in output', [
                'video_id' => $videoId,
                'output'   => substr($output, 0, 500),
            ]);
            return ['stream_url' => null, 'format' => null, 'error' => 'YTDLP_NO_URL'];
        }

        $streamUrl = array_values($lines)[0];

        // Deteksi format dari URL
        $format = 'm4a';
        if (str_contains($streamUrl, 'mime=audio/webm') || str_contains($streamUrl, '.webm')) {
            $format = 'webm';
        } elseif (str_contains($streamUrl, 'mime=audio/mp4') || str_contains($streamUrl, '.m4a')) {
            $format = 'm4a';
        }

        Log::info('[YtDlpService] Stream URL resolved successfully', [
            'video_id' => $videoId,
            'format'   => $format,
        ]);

        return [
            'stream_url' => $streamUrl,
            'format'     => $format,
            'error'      => null,
        ];
    }

    /**
     * Dapatkan direct audio stream URL dari sembarang URL (seperti SoundCloud)
     */
    public function resolveDirectUrl(string $url): array
    {
        $formatSelector = 'bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio';

        $command = sprintf(
            '%s -f "%s" --get-url --no-playlist --socket-timeout %d "%s" 2>&1',
            escapeshellcmd($this->ytdlpPath),
            $formatSelector,
            $this->timeout,
            $url
        );

        Log::info('[YtDlpService] Resolving direct stream URL', [
            'url'      => $url,
            'command'  => $command,
        ]);

        $startTime = microtime(true);
        $output    = shell_exec($command);
        $elapsed   = round(microtime(true) - $startTime, 2);

        if (empty($output)) {
            Log::error('[YtDlpService] Empty output from yt-dlp', ['url' => $url]);
            return ['stream_url' => null, 'format' => null, 'error' => 'YTDLP_EMPTY_OUTPUT'];
        }

        $lines = array_filter(
            array_map('trim', explode("\n", trim($output))),
            fn($line) => str_starts_with($line, 'http')
        );

        if (empty($lines)) {
            Log::error('[YtDlpService] No valid URL in output', [
                'url'      => $url,
                'output'   => substr($output, 0, 500),
            ]);
            return ['stream_url' => null, 'format' => null, 'error' => 'YTDLP_NO_URL'];
        }

        $streamUrl = array_values($lines)[0];

        $format = 'm4a';
        if (str_contains($streamUrl, 'mime=audio/webm') || str_contains($streamUrl, '.webm')) {
            $format = 'webm';
        } elseif (str_contains($streamUrl, 'mime=audio/mp4') || str_contains($streamUrl, '.m4a')) {
            $format = 'm4a';
        }

        return [
            'stream_url' => $streamUrl,
            'format'     => $format,
            'error'      => null,
        ];
    }

    /**
     * Cek apakah yt-dlp terinstall dan bisa dijalankan
     */
    public function isAvailable(): bool
    {
        $output = shell_exec("{$this->ytdlpPath} --version 2>&1");
        return !empty($output) && preg_match('/\d{4}\.\d+\.\d+/', trim($output));
    }

    /**
     * Dapatkan versi yt-dlp yang terinstall
     */
    public function getVersion(): ?string
    {
        $output = shell_exec("{$this->ytdlpPath} --version 2>&1");
        if ($output && preg_match('/(\d{4}\.\d+\.\d+)/', trim($output), $matches)) {
            return $matches[1];
        }
        return null;
    }

    /**
     * Dapatkan direct audio stream URL dari pencarian YouTube (Fallback)
     */
    public function resolveBySearch(string $query): array
    {
        // Ekstrak variasi query untuk memperluas kemungkinan pencarian
        // Default query dari iTunes biasanya berformat: "Artist - Title audio"
        $variations = [$query];
        
        $cleanQuery = trim(str_replace(' audio', '', $query));
        if ($cleanQuery !== $query) {
            $variations[] = $cleanQuery; // Versi tanpa kata "audio"
        }
        
        // Coba ekstrak hanya judul (setelah tanda "-")
        if (str_contains($cleanQuery, ' - ')) {
            $parts = explode(' - ', $cleanQuery, 2);
            if (isset($parts[1]) && !empty(trim($parts[1]))) {
                $variations[] = trim($parts[1]); // Hanya judul lagu
            }
        }

        // Definisi urutan prioritas mesin pencari (YouTube harus pertama karena algoritmanya jauh lebih akurat)
        $engines = ['ytsearch1:', 'scsearch1:'];
        
        // Buat matriks kombinasi (Engine x Variation)
        $searchMatrix = [];
        foreach ($engines as $engine) {
            foreach ($variations as $var) {
                $searchMatrix[] = $engine . $var;
            }
        }
        
        // Kita akan melakukan fallback secara masif melintasi matriks ini!
        foreach ($searchMatrix as $videoUrl) {
            $formatSelector = 'bestaudio[ext=m4a]/bestaudio[ext=webm]/bestaudio';

            $command = sprintf(
                '%s -f "%s" --get-url --no-playlist --socket-timeout %d "%s" 2>&1',
                escapeshellcmd($this->ytdlpPath),
                $formatSelector,
                $this->timeout,
                $videoUrl
            );

            Log::info('[YtDlpService] Resolving stream URL by search', [
                'original_query' => $query,
                'search_target'  => $videoUrl,
                'command'        => $command,
            ]);

            $startTime = microtime(true);
            $output    = shell_exec($command);
            $elapsed   = round(microtime(true) - $startTime, 2);

            if (empty($output)) {
                Log::warning('[YtDlpService] Empty output from yt-dlp search', ['target' => $videoUrl]);
                continue; // Coba sumber berikutnya (fallback)
            }

            $lines = array_filter(
                array_map('trim', explode("\n", trim($output))),
                fn($line) => str_starts_with($line, 'http')
            );

            if (empty($lines)) {
                Log::warning('[YtDlpService] No valid URL in output (Search)', [
                    'target' => $videoUrl,
                    'output' => substr($output, 0, 500),
                ]);
                continue; // Coba sumber berikutnya (fallback)
            }

            $streamUrl = array_values($lines)[0];

            $format = 'm4a';
            if (str_contains($streamUrl, 'mime=audio/webm') || str_contains($streamUrl, '.webm')) {
                $format = 'webm';
            } elseif (str_contains($streamUrl, 'mime=audio/mp4') || str_contains($streamUrl, '.m4a')) {
                $format = 'm4a';
            }

            Log::info('[YtDlpService] Stream URL resolved successfully by search', [
                'target' => $videoUrl,
                'format' => $format,
            ]);

            return [
                'stream_url' => $streamUrl,
                'format'     => $format,
                'error'      => null,
            ];
        }

        // Jika semua sumber gagal
        Log::error('[YtDlpService] All search sources failed', ['query' => $query]);
        return ['stream_url' => null, 'format' => null, 'error' => 'YTDLP_NO_URL'];
    }
}
