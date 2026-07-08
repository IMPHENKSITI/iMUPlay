import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../playlists/providers/database_provider.dart';
import '../search/models/online_song_model.dart';

// ── State ──────────────────────────────────────────────────────────────────────

enum SyncStatus { idle, syncing, success, error }

class CloudSyncState {
  final SyncStatus status;
  final String? message;

  const CloudSyncState({this.status = SyncStatus.idle, this.message});
}

// ── Provider ───────────────────────────────────────────────────────────────────

final cloudSyncProvider =
    StateNotifierProvider<CloudSyncNotifier, CloudSyncState>((ref) {
  final notifier = CloudSyncNotifier(ref);

  // Auto-sync listener untuk memantau perubahan
  ref.listen(onlinePlaylistsProvider, (previous, next) {
    if (notifier.isPulling) return;
    if (previous != null) {
      notifier.pushSync();
    }
  });

  ref.listen(onlineFavoritesProvider, (previous, next) {
    if (notifier.isPulling) return;
    if (previous != null) {
      notifier.pushSync();
    }
  });

  return notifier;
});

class CloudSyncNotifier extends StateNotifier<CloudSyncState> {
  CloudSyncNotifier(this._ref) : super(const CloudSyncState());

  final Ref _ref;
  final _dio = DioClient.instance;
  bool isPulling = false;

  /// Push semua Online Playlist + Liked Songs ke server Laravel.
  /// Dipanggil setelah login atau saat user menekan tombol sync.
  Future<void> pushSync() async {
    state = const CloudSyncState(status: SyncStatus.syncing);
    try {
      final playlists  = _ref.read(onlinePlaylistsProvider);
      final likedSongs = _ref.read(onlineFavoritesProvider);

      // Bangun payload
      final payload = <Map<String, dynamic>>[];

      // Online Playlists (type: 'playlist')
      for (final playlist in playlists) {
        payload.add({
          'name': playlist.name,
          'type': 'playlist',
          'items': playlist.songs.asMap().entries.map((entry) {
            final i    = entry.key;
            final song = entry.value;
            return {
              'song_id':          song.id,
              'title':            song.title,
              'artist':           song.artist,
              'thumbnail_url':    song.thumbnail,
              'duration_seconds': song.duration,
              'sort_order':       i,
            };
          }).toList(),
        });
      }

      // Liked Songs (type: 'liked_songs') — disimpan sebagai satu playlist khusus
      if (likedSongs.isNotEmpty) {
        payload.add({
          'name': 'Liked Songs',
          'type': 'liked_songs',
          'items': likedSongs.asMap().entries.map((entry) {
            final i    = entry.key;
            final song = entry.value;
            return {
              'song_id':          song.id,
              'title':            song.title,
              'artist':           song.artist,
              'thumbnail_url':    song.thumbnail,
              'duration_seconds': song.duration,
              'sort_order':       i,
            };
          }).toList(),
        });
      }

      await _dio.post('/sync', data: {'playlists': payload});

      state = const CloudSyncState(
        status: SyncStatus.success,
        message: 'Sinkronisasi berhasil!',
      );
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 401
          ? 'Sesi berakhir. Silakan login ulang.'
          : 'Gagal sinkronisasi: ${e.message}';
      state = CloudSyncState(status: SyncStatus.error, message: msg);
    }
  }

  /// Pull data cloud dari server dan restore ke Hive lokal.
  /// Dipanggil pertama kali setelah user login.
  Future<void> pullSync() async {
    isPulling = true;
    state = const CloudSyncState(status: SyncStatus.syncing);
    try {
      final response = await _dio.get('/sync');
      final playlists = response.data['playlists'] as List;

      final onlinePlaylists  = _ref.read(onlinePlaylistsProvider.notifier);
      final onlineFavorites  = _ref.read(onlineFavoritesProvider.notifier);

      for (final p in playlists) {
        final name  = p['name'] as String;
        final type  = p['type'] as String;
        final items = (p['items'] as List).map((item) {
          return _itemToOnlineSong(item as Map<String, dynamic>);
        }).toList();

        if (type == 'liked_songs') {
          onlineFavorites.addFavorites(items);
        } else {
          onlinePlaylists.createPlaylist(name);
          onlinePlaylists.addSongsToPlaylist(name, items);
        }
      }

      state = const CloudSyncState(
        status: SyncStatus.success,
        message: 'Data cloud berhasil dimuat.',
      );
    } on DioException catch (_) {
      // Pull gagal tidak fatal — data lokal tetap ada
      state = const CloudSyncState(status: SyncStatus.idle);
    } finally {
      // Beri sedikit delay sebelum mengizinkan push otomatis
      // untuk memastikan state UI sudah settle
      Future.delayed(const Duration(milliseconds: 500), () {
        isPulling = false;
      });
    }
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  OnlineSongModel _itemToOnlineSong(Map<String, dynamic> item) {
    return OnlineSongModel(
      id:              item['song_id'] as String,
      title:           item['title'] as String,
      artist:          item['artist'] as String? ?? 'Unknown',
      thumbnail:       item['thumbnail_url'] as String?,
      duration:        item['duration_seconds'] as int? ?? 0,
      // Fields berikut tidak disimpan di cloud — isi dengan placeholder
      source:          'cloud',
      streamReference: item['song_id'] as String,
      streamMechanism: 'cloud',
      isStreamable:    false,
    );
  }
}
