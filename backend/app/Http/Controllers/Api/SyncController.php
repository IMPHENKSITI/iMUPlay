<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CloudPlaylist;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SyncController extends Controller
{
    /**
     * Menerima payload sinkronisasi dari Flutter dan menyimpannya ke database.
     *
     * Payload JSON yang diharapkan:
     * {
     *   "playlists": [
     *     {
     *       "name": "My Playlist",
     *       "type": "playlist",
     *       "items": [
     *         {
     *           "song_id": "online:youtube:dQw4w9WgXcQ",
     *           "title": "Never Gonna Give You Up",
     *           "artist": "Rick Astley",
     *           "thumbnail_url": "https://...",
     *           "duration_seconds": 213,
     *           "sort_order": 0
     *         }
     *       ]
     *     }
     *   ]
     * }
     */
    public function sync(Request $request)
    {
        $request->validate([
            'playlists'                     => 'required|array',
            'playlists.*.name'              => 'required|string|max:255',
            'playlists.*.type'              => 'required|in:playlist,liked_songs',
            'playlists.*.items'             => 'required|array',
            'playlists.*.items.*.song_id'   => 'required|string',
            'playlists.*.items.*.title'     => 'required|string',
            'playlists.*.items.*.artist'    => 'nullable|string',
            'playlists.*.items.*.thumbnail_url'     => 'nullable|string',
            'playlists.*.items.*.duration_seconds'  => 'nullable|integer',
            'playlists.*.items.*.sort_order'        => 'nullable|integer',
        ]);

        $user = $request->user();

        DB::transaction(function () use ($user, $request) {
            // Hapus semua data lama milik user ini, lalu tulis ulang yang baru
            // (full-replace sync strategy = simpel dan reliable)
            $user->cloudPlaylists()->delete();

            foreach ($request->playlists as $playlistData) {
                $playlist = $user->cloudPlaylists()->create([
                    'name' => $playlistData['name'],
                    'type' => $playlistData['type'],
                ]);

                $items = [];
                foreach ($playlistData['items'] as $item) {
                    $items[] = [
                        'cloud_playlist_id' => $playlist->id,
                        'song_id'           => $item['song_id'],
                        'title'             => $item['title'],
                        'artist'            => $item['artist'] ?? null,
                        'thumbnail_url'     => $item['thumbnail_url'] ?? null,
                        'duration_seconds'  => $item['duration_seconds'] ?? null,
                        'sort_order'        => $item['sort_order'] ?? 0,
                        'created_at'        => now(),
                        'updated_at'        => now(),
                    ];
                }

                if (! empty($items)) {
                    \App\Models\CloudPlaylistItem::insert($items);
                }
            }
        });

        return response()->json([
            'message'          => 'Sinkronisasi berhasil.',
            'playlists_synced' => count($request->playlists),
        ]);
    }

    /**
     * Ambil semua data cloud milik user (untuk restore saat login di device baru).
     */
    public function pull(Request $request)
    {
        $user = $request->user();

        $playlists = $user->cloudPlaylists()->with('items')->get()->map(function ($playlist) {
            return [
                'name'  => $playlist->name,
                'type'  => $playlist->type,
                'items' => $playlist->items->map(function ($item) {
                    return [
                        'song_id'          => $item->song_id,
                        'title'            => $item->title,
                        'artist'           => $item->artist,
                        'thumbnail_url'    => $item->thumbnail_url,
                        'duration_seconds' => $item->duration_seconds,
                        'sort_order'       => $item->sort_order,
                    ];
                }),
            ];
        });

        return response()->json(['playlists' => $playlists]);
    }
}
