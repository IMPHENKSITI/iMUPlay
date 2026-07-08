<?php

namespace App\Services\Providers\Contracts;

use App\DTOs\UnifiedTrackDTO;

interface MusicProviderInterface
{
    /**
     * Nama provider (youtube, audius, jamendo, itunes)
     */
    public function getName(): string;

    /**
     * Cari lagu berdasarkan query
     * @return UnifiedTrackDTO[]
     */
    public function search(string $query, int $limit = 10): array;

    /**
     * Cek apakah provider ini sedang bisa diakses
     */
    public function isAvailable(): bool;
}
