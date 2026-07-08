<?php

namespace App\Services;

use App\DTOs\UnifiedTrackDTO;
use App\Services\Providers\Contracts\MusicProviderInterface;
use Illuminate\Support\Facades\Log;

class MusicOrchestratorService
{
    /** @var MusicProviderInterface[] */
    private array $providers;

    public function __construct(array $providers)
    {
        $this->providers = $providers;
    }

    /**
     * Cari musik dari semua provider secara paralel (menggunakan fiber / concurrent)
     * Hanya provider yang isAvailable() = true yang diquery
     *
     * @param string   $query
     * @param string[] $selectedProviders  kosong = semua provider
     * @param int      $limit              jumlah hasil per provider
     * @return array{results: UnifiedTrackDTO[], providers_queried: string[], providers_failed: string[], providers_skipped: string[]}
     */
    public function search(string $query, array $selectedProviders = [], int $limit = 10): array
    {
        $results          = [];
        $providersQueried = [];
        $providersFailed  = [];
        $providersSkipped = [];

        foreach ($this->providers as $provider) {
            $name = $provider->getName();

            // Filter provider jika ada yang dipilih
            if (!empty($selectedProviders) && !in_array($name, $selectedProviders)) {
                continue;
            }

            // Skip provider yang tidak tersedia (key tidak ada, dll)
            if (!$provider->isAvailable()) {
                $providersSkipped[] = $name;
                Log::info("[Orchestrator] Provider '{$name}' skipped — not available.");
                continue;
            }

            try {
                $tracks = $provider->search($query, $limit);
                $results = array_merge($results, $tracks);
                $providersQueried[] = $name;

                Log::info("[Orchestrator] Provider '{$name}' returned " . count($tracks) . " tracks.");

            } catch (\Throwable $e) {
                $providersFailed[] = $name;
                Log::error("[Orchestrator] Provider '{$name}' threw exception", [
                    'message' => $e->getMessage(),
                ]);
            }
        }

        $results = $this->sortResultsByRelevance($results, $query);

        return [
            'results'           => $results,
            'providers_queried' => $providersQueried,
            'providers_failed'  => $providersFailed,
            'providers_skipped' => $providersSkipped,
        ];
    }

    /**
     * Mengurutkan hasil pencarian berdasarkan tingkat kemiripan dengan query.
     * Lagu yang judul dan artisnya mengandung query (atau sebaliknya) akan diprioritaskan.
     *
     * @param UnifiedTrackDTO[] $results
     * @param string $query
     * @return UnifiedTrackDTO[]
     */
    private function sortResultsByRelevance(array $results, string $query): array
    {
        $queryLower = strtolower(trim($query));
        
        // Ekstrak kata-kata dari query untuk pencocokan parsial
        $queryWords = array_filter(explode(' ', $queryLower));

        usort($results, function (UnifiedTrackDTO $a, UnifiedTrackDTO $b) use ($queryLower, $queryWords) {
            $scoreA = $this->calculateRelevanceScore($a, $queryLower, $queryWords);
            $scoreB = $this->calculateRelevanceScore($b, $queryLower, $queryWords);

            // Urutkan menurun (score tertinggi di atas)
            if ($scoreA === $scoreB) {
                return 0;
            }
            return ($scoreA > $scoreB) ? -1 : 1;
        });

        return $results;
    }

    private function calculateRelevanceScore(UnifiedTrackDTO $track, string $queryLower, array $queryWords): int
    {
        $title = strtolower($track->title);
        $artist = strtolower($track->artist);
        $combined = $title . ' ' . $artist;

        $score = 0;

        // 1. Exact match di judul ATAU kombinasi judul+artis
        if ($title === $queryLower || str_contains($combined, $queryLower)) {
            $score += 100;
        }

        // 2. Exact match dari nama artis
        if ($artist === $queryLower) {
            $score += 80;
        }

        // 3. Semua kata di query ada di judul/artis (Fuzzy Exact Match)
        $allWordsFound = true;
        foreach ($queryWords as $word) {
            if (!str_contains($combined, $word)) {
                $allWordsFound = false;
                break;
            }
        }
        
        if ($allWordsFound && count($queryWords) > 1) {
            $score += 50;
        }

        // 4. Sebagian kata ditemukan
        $wordsFound = 0;
        foreach ($queryWords as $word) {
            if (str_contains($combined, $word)) {
                $wordsFound++;
            }
        }
        $score += ($wordsFound * 10);

        // 5. Penalti untuk judul yang terlalu panjang (kemungkinan kompilasi/interview)
        // Jika query pendek, tapi lagunya 1 jam (podcast/interview) atau judulnya sangat panjang
        if (strlen($title) > 60) {
            $score -= 20;
        }

        // 6. Prioritaskan iTunes agar lagu orisinal/resmi muncul paling atas
        if ($track->source === 'itunes') {
            $score += 1000; // Bonus super besar agar iTunes (lagu ori) mutlak naik ke atas
        }

        return $score;
    }
}
