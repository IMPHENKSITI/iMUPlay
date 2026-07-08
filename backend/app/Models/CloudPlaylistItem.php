<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CloudPlaylistItem extends Model
{
    protected $fillable = [
        'cloud_playlist_id',
        'song_id',
        'title',
        'artist',
        'thumbnail_url',
        'duration_seconds',
        'sort_order',
    ];

    public function playlist(): BelongsTo
    {
        return $this->belongsTo(CloudPlaylist::class, 'cloud_playlist_id');
    }
}
