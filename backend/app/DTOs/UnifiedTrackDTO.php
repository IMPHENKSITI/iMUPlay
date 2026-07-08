<?php

namespace App\DTOs;

class UnifiedTrackDTO
{
    public function __construct(
        public readonly string  $id,
        public readonly string  $title,
        public readonly string  $artist,
        public readonly ?string $album,
        public readonly ?string $thumbnail,
        public readonly string  $source,           // youtube | audius | jamendo | itunes | local
        public readonly string  $streamReference,  // video_id / track_id / direct_url
        public readonly string  $streamMechanism,  // ytdlp | audius_api | direct_url
        public readonly int     $duration,         // detik
        public readonly bool    $isStreamable,
        public readonly array   $providerMetadata = [],
    ) {}

    public function toArray(): array
    {
        return [
            'id'                => $this->id,
            'title'             => $this->title,
            'artist'            => $this->artist,
            'album'             => $this->album,
            'thumbnail'         => $this->thumbnail,
            'source'            => $this->source,
            'stream_reference'  => $this->streamReference,
            'stream_mechanism'  => $this->streamMechanism,
            'duration'          => $this->duration,
            'is_streamable'     => $this->isStreamable,
            'provider_metadata' => $this->providerMetadata,
        ];
    }
}
