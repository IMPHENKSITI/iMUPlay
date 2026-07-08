import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:audio_session/audio_session.dart';

import '../../../core/audio/audio_handler.dart';
import '../services/audio_session_manager.dart';
import '../repositories/stream_url_repository.dart';
import '../../search/models/online_song_model.dart';
import '../services/audio_cache_manager.dart';
import '../../playlists/providers/database_provider.dart';
import '../../history/providers/history_provider.dart';
import 'dart:io';
import 'dart:math';

// Provides the raw AudioPlayer instance from global handler
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  return globalAudioHandler.player;
});

// A StateNotifier to manage our custom playback logic and queue
final audioHandlerProvider = StateNotifierProvider<AudioHandlerNotifier, AsyncValue<SongModel?>>((ref) {
  return AudioHandlerNotifier(
    ref,
    ref.watch(audioPlayerProvider),
    ref.watch(streamUrlRepositoryProvider),
  );
});

class AudioHandlerNotifier extends StateNotifier<AsyncValue<SongModel?>> {
  final Ref _ref;
  final AudioPlayer _player;
  final StreamUrlRepository _streamRepo;
  List<SongModel> _currentQueue = [];
  int _currentIndex = -1;
  ConcatenatingAudioSource? _localPlaylist;

  bool _isManualQueue = false;
  CancelToken? _currentDownloadToken;

  List<int> _shuffledIndices = [];
  int _shuffleIndex = -1;

  void _ensureShuffledIndices() {
    if (_shuffledIndices.length != _currentQueue.length) {
      _shuffledIndices = List.generate(_currentQueue.length, (i) => i);
      _shuffledIndices.shuffle(Random());
      _shuffleIndex = _shuffledIndices.indexOf(_currentIndex);
      if (_shuffleIndex == -1) {
        _shuffleIndex = 0;
        if (_shuffledIndices.isNotEmpty) {
          _currentIndex = _shuffledIndices[0];
        }
      }
    }
  }

  AudioHandlerNotifier(this._ref, this._player, this._streamRepo) : super(const AsyncValue.data(null)) {
    globalAudioHandler.onSkipToNextCb = skipToNext;
    globalAudioHandler.onSkipToPreviousCb = skipToPrevious;
    _initListeners();
  }

  Future<void> _updateMediaItem(SongModel song) async {
    Uri? artUri = (song.uri != null && song.uri!.startsWith('http')) ? Uri.parse(song.uri!) : null;

    // Jika lagu lokal (bukan online) dan belum ada artUri
    if (artUri == null && !song.data.startsWith('online:')) {
      final cachedPath = await AudioCacheManager.getArtworkCacheFilePath(song.id);
      if (await File(cachedPath).exists()) {
        artUri = Uri.file(cachedPath);
      } else {
        final OnAudioQuery audioQuery = OnAudioQuery();
        final bytes = await audioQuery.queryArtwork(song.id, ArtworkType.AUDIO);
        if (bytes != null) {
          final savedPath = await AudioCacheManager.cacheArtwork(song.id, bytes);
          if (savedPath != null) {
            artUri = Uri.file(savedPath);
          }
        }
      }
    }

    globalAudioHandler.mediaItem.add(
      MediaItem(
        id: song.id.toString(),
        album: song.album ?? "",
        title: song.title,
        artist: song.artist ?? "Unknown Artist",
        duration: song.duration != null ? Duration(milliseconds: song.duration!) : null,
        artUri: artUri,
      ),
    );
  }

  void _syncQueueToAudioService() {
    final mediaItems = _currentQueue.map((song) => MediaItem(
      id: song.id.toString(),
      album: song.album ?? "",
      title: song.title,
      artist: song.artist ?? "Unknown Artist",
      duration: song.duration != null ? Duration(milliseconds: song.duration!) : null,
      artUri: (song.uri != null && song.uri!.startsWith('http')) ? Uri.parse(song.uri!) : null,
    )).toList();
    globalAudioHandler.queue.add(mediaItems);
  }

  void _initListeners() {
    _player.shuffleModeEnabledStream.listen((enabled) {
      if (!enabled) {
        _shuffledIndices.clear();
        _shuffleIndex = -1;
      }
    });

    _player.currentIndexStream.listen((index) {
      if (!_isManualQueue && index != null && index < _currentQueue.length) {
        _currentIndex = index;
        final song = _currentQueue[index];
        state = AsyncValue.data(song);
        _ref.read(historyProvider.notifier).addSongToHistory(song);
        _updateMediaItem(song);
      }
    });

    bool hasHandledCompletion = false;

    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (hasHandledCompletion) return;
        hasHandledCompletion = true;
        
        final repeatMode = globalAudioHandler.playbackState.value.repeatMode;
        
        if (_isManualQueue) {
          final isShuffle = _player.shuffleModeEnabled;
          if (repeatMode == AudioServiceRepeatMode.one || (repeatMode == AudioServiceRepeatMode.all && _currentQueue.length == 1)) {
            _player.seek(Duration.zero);
            globalAudioHandler.play();
          } else if (isShuffle && _currentQueue.length > 1) {
            _ensureShuffledIndices();
            if (_shuffleIndex < _shuffledIndices.length - 1) {
              _shuffleIndex++;
              _currentIndex = _shuffledIndices[_shuffleIndex];
              _playCurrentIndex();
            } else if (repeatMode == AudioServiceRepeatMode.all) {
              _shuffleIndex = 0;
              _currentIndex = _shuffledIndices[_shuffleIndex];
              _playCurrentIndex();
            } else {
              globalAudioHandler.pause();
              _player.seek(Duration.zero);
            }
          } else if (repeatMode == AudioServiceRepeatMode.all) {
            if (_currentIndex < _currentQueue.length - 1) {
              _currentIndex++;
              _playCurrentIndex();
            } else {
              _currentIndex = 0;
              _playCurrentIndex();
            }
          } else {
            // AudioServiceRepeatMode.none
            if (_currentIndex < _currentQueue.length - 1) {
              _currentIndex++;
              _playCurrentIndex();
            } else {
              globalAudioHandler.pause();
              _player.seek(Duration.zero);
            }
          }
        } else {
          // Local gapless playlist (ConcatenatingAudioSource)
          // Since we disable native loop mode, we must handle its loop manually too!
          if (repeatMode == AudioServiceRepeatMode.one) {
            _player.seek(Duration.zero, index: _currentIndex);
            globalAudioHandler.play();
          } else if (repeatMode == AudioServiceRepeatMode.all) {
            if (_currentIndex < _currentQueue.length - 1) {
              _player.seekToNext();
            } else {
              _player.seek(Duration.zero, index: 0);
            }
          } else {
            // AudioServiceRepeatMode.none
            if (_currentIndex < _currentQueue.length - 1) {
              _player.seekToNext();
            } else {
              globalAudioHandler.pause();
              _player.seek(Duration.zero, index: _currentIndex);
            }
          }
        }
      } else {
        hasHandledCompletion = false;
      }
    });

    AudioSession.instance.then((session) {
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.2);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              final prefs = AudioSessionManager.focusPreference;
              if (prefs == 1) { // Hormati Aplikasi Lain
                globalAudioHandler.pause();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Playback resume could be handled here if needed
              break;
          }
        }
      });
    });

    _player.playbackEventStream.listen((event) {}, onError: (Object e, StackTrace stackTrace) {
      debugPrint('A stream error occurred: $e');
      // Intentionally not setting state = AsyncValue.error here because this is often triggered
      // by simply skipping songs rapidly (aborting previous stream requests).
    });
  }

  Future<void> _playCurrentIndex() async {
    if (_currentIndex < 0 || _currentIndex >= _currentQueue.length) return;
    
    // Jangan pause player agar Service tidak mati di background
    // Mute volume saja sementara memuat lagu baru.
    await _player.setVolume(0.0);

    final song = _currentQueue[_currentIndex];
    // Langsung update UI dan Notifikasi dengan lagu baru agar terasa instan
    state = AsyncValue.data(song);
    _updateMediaItem(song);
    _ref.read(historyProvider.notifier).addSongToHistory(song);
    
    try {
      if (song.data.startsWith('online:')) {
        // Resolve stream URL just in time
        final parts = song.data.split(':');
        // format: online:source:id:mechanism:streamReference
        final source = parts[1];
        final id = parts[2];
        final mechanism = parts[3];
        final streamRef = parts.length > 4 ? parts.sublist(4).join(':') : '';
        
        final cachePath = await AudioCacheManager.getCacheFilePath(streamRef);
        final file = File(cachePath);
        
        final mediaItem = MediaItem(
          id: song.id.toString(),
          album: song.album ?? "Online",
          title: song.title,
          artist: song.artist ?? "Unknown Artist",
          artUri: song.uri != null ? Uri.parse(song.uri!) : null,
        );

        // Record metadata to CacheManager for TTL
        String criteria = 'search';
        final favorites = _ref.read(onlineFavoritesProvider);
        if (favorites.any((s) => s.id == id && s.source == source)) {
          criteria = 'favorite';
        } else {
          final playlists = _ref.read(onlinePlaylistsProvider);
          bool found = false;
          for (var p in playlists) {
            if (p.songs.any((s) => s.id == id && s.source == source)) {
              found = true;
              break;
            }
          }
          if (found) criteria = 'playlist';
        }

        // 1. Jika file cache sudah ada, artinya 100% komplit. Mainkan langsung secara OFFLINE.
        if (await file.exists()) {
          try {
            await _player.setAudioSource(AudioSource.file(file.path, tag: mediaItem));
            AudioCacheManager.cacheOrUpdateSong(streamRef, criteria);
          } catch (e) {
            debugPrint("Cache playback failed: $e. Corrupted cache. Deleting...");
            try { await file.delete(); } catch (_) {}
          }
        }

        // 2. Jika file belum ada (atau gagal dimainkan), butuh internet untuk stream & download.
        if (!await file.exists()) {
          final duration = song.duration != null ? (song.duration! ~/ 1000) : 0;
          final url = await _streamRepo.getStreamUrl(source, streamRef, mechanism: mechanism, duration: duration);
          if (url == null) throw Exception("Gagal mendapatkan URL stream");
          
          final uri = Uri.parse(url);

          // Batalkan download lagu sebelumnya jika masih berjalan
          _currentDownloadToken?.cancel();
          _currentDownloadToken = CancelToken();

          final tempPath = '$cachePath.tmp';
          
          // Mulai download di background tanpa mem-block pemutaran
          Dio().download(
            url,
            tempPath,
            cancelToken: _currentDownloadToken,
          ).then((_) async {
            // Setelah 100% komplit, ganti nama file jadi .mp3 agar bisa diputar offline nanti
            final tmpFile = File(tempPath);
            if (await tmpFile.exists()) {
              await tmpFile.rename(cachePath);
              AudioCacheManager.cacheOrUpdateSong(streamRef, criteria);
            }
          }).catchError((e) {
            // Abaikan error (misal batal karena di-skip, atau koneksi putus)
            try { File(tempPath).deleteSync(); } catch (_) {}
          });

          // Mainkan streaming
          await _player.setAudioSource(AudioSource.uri(uri));
        }
      } else {
        await _player.setAudioSource(
          AudioSource.file(song.data),
        );
      }
      await _player.setVolume(1.0);
      globalAudioHandler.play();
      state = AsyncValue.data(song);
      } catch (e, stack) {
        await _player.setVolume(1.0);
        debugPrint("===== PLAY CURRENT INDEX ERROR =====");
        debugPrint(e.toString());
        
        String errorMsg = "Terjadi kesalahan saat memutar lagu.";
        if (e.toString().contains('DioException')) {
          if (e.toString().contains('422')) {
            errorMsg = "Lagu ini tidak dapat diputar (mungkin dibatasi wilayah atau sumber aslinya). Melewati ke lagu berikutnya...";
          } else {
            errorMsg = "Gagal memuat lagu. Periksa koneksi internet Anda.";
          }
        }
        
        state = AsyncValue.error(Exception(errorMsg), stack);
        
        // Auto-skip ke lagu berikutnya jika masih ada di antrean
        if (_isManualQueue && _currentIndex < _currentQueue.length - 1) {
          Future.delayed(const Duration(seconds: 3), () {
            // Cek apakah user belum berpindah lagu manual
            if (state.hasError) {
               skipToNext();
            }
          });
        }
      }
  }

  Future<void> playSong(SongModel song, {List<SongModel>? queue}) async {
    try {
      state = const AsyncValue.loading();
      
      if (queue != null) {
        _currentQueue = queue;
      } else {
        _currentQueue = [song];
      }
      
      _syncQueueToAudioService();

      _currentIndex = _currentQueue.indexWhere((s) => s.id == song.id);
      if (_currentIndex == -1) _currentIndex = 0;

      final hasOnline = _currentQueue.any((s) => s.data.startsWith('online:') || s.data.startsWith('http'));

      if (hasOnline) {
        // Use manual queue for online songs
        _isManualQueue = true;
        await _playCurrentIndex();
      } else {
        // Use ConcatenatingAudioSource for gapless local playback
        _isManualQueue = false;
        final audioSources = _currentQueue.map((s) {
          return AudioSource.file(s.data);
        }).toList();

        _localPlaylist = ConcatenatingAudioSource(children: audioSources);

        await _player.setAudioSource(
          _localPlaylist!,
          initialIndex: _currentIndex,
          initialPosition: Duration.zero,
        );
        
        globalAudioHandler.play();
        state = AsyncValue.data(song);
      }
    } catch (e, stack) {
      debugPrint("===== PLAY SONG ERROR =====");
      debugPrint(e.toString());
      debugPrint(stack.toString());
      state = AsyncValue.error(e, stack);
    }
  }

  // Khusus memutar lagu online, bisa dengan queue
  Future<void> playOnlineSong(OnlineSongModel onlineSong, {List<OnlineSongModel>? queue}) async {
    try {
      state = const AsyncValue.loading();
      
      List<SongModel>? fauxQueue;
      if (queue != null) {
        fauxQueue = queue.map((q) => SongModel({
          '_id': q.id.hashCode,
          'title': q.title,
          'artist': q.artist,
          'album': q.album ?? 'Unknown Album',
          '_data': 'online:${q.source}:${q.id}:${q.streamMechanism}:${q.streamReference}',
          '_uri': q.thumbnail,
          'duration': q.duration * 1000,
        })).toList();
      }

      final fauxSong = SongModel({
        '_id': onlineSong.id.hashCode,
        'title': onlineSong.title,
        'artist': onlineSong.artist,
        'album': onlineSong.album ?? 'Unknown Album',
        '_data': 'online:${onlineSong.source}:${onlineSong.id}:${onlineSong.streamMechanism}:${onlineSong.streamReference}',
        '_uri': onlineSong.thumbnail,
        'duration': onlineSong.duration * 1000,
      });

      await playSong(fauxSong, queue: fauxQueue);
    } catch (e, stack) {
      debugPrint("===== PLAY ONLINE SONG ERROR =====");
      debugPrint(e.toString());
      state = AsyncValue.error(e, stack);
    }
  }

  void play() => globalAudioHandler.play();
  void pause() => globalAudioHandler.pause();
  void seek(Duration position, {int? index}) {
    if (_isManualQueue && index != null && index != _currentIndex) {
      _currentIndex = index;
      _playCurrentIndex().then((_) {
        if (position != Duration.zero) _player.seek(position);
      });
    } else {
      _player.seek(position, index: _isManualQueue ? null : index);
    }
  }
  
  void addToQueue(SongModel song) {
    if (_currentQueue.isEmpty) {
      playSong(song);
      return;
    }

    _currentQueue = List.from(_currentQueue)..add(song);
    _syncQueueToAudioService();
    
    if (!_isManualQueue && _localPlaylist != null) {
      _localPlaylist!.add(
        AudioSource.file(
          song.data,
          tag: MediaItem(
            id: song.id.toString(),
            album: song.album ?? "Unknown Album",
            title: song.title,
            artist: song.artist ?? "Unknown Artist",
          ),
        ),
      );
    }
    
    if (state.valueOrNull != null) {
      state = AsyncValue.data(state.valueOrNull!);
    }
  }

  void addOnlineSongToQueue(OnlineSongModel onlineSong) {
    final fauxSong = SongModel({
      '_id': onlineSong.id.hashCode,
      'title': onlineSong.title,
      'artist': onlineSong.artist,
      'album': onlineSong.album ?? 'Unknown Album',
      '_data': 'online:${onlineSong.source}:${onlineSong.id}:${onlineSong.streamMechanism}:${onlineSong.streamReference}',
      '_uri': onlineSong.thumbnail,
      'duration': onlineSong.duration * 1000,
    });
    addToQueue(fauxSong);
  }

  void addMultipleOnlineToQueue(List<OnlineSongModel> onlineSongs) {
    if (onlineSongs.isEmpty) return;

    final fauxSongs = onlineSongs.map((q) => SongModel({
      '_id': q.id.hashCode,
      'title': q.title,
      'artist': q.artist,
      'album': q.album ?? 'Unknown Album',
      '_data': 'online:${q.source}:${q.id}:${q.streamMechanism}:${q.streamReference}',
      '_uri': q.thumbnail,
      'duration': q.duration * 1000,
    })).toList();

    if (_currentQueue.isEmpty) {
      playSong(fauxSongs.first, queue: fauxSongs);
      return;
    }

    _currentQueue = List.from(_currentQueue)..addAll(fauxSongs);
    _syncQueueToAudioService();

    if (state.valueOrNull != null) {
      state = AsyncValue.data(state.valueOrNull!);
    }
  }

void removeFromQueue(int index) {
    if (index < 0 || index >= _currentQueue.length) return;
    
    // For simplicity, prevent removing the currently playing song
    if (index == _currentIndex) return;

    _currentQueue = List.from(_currentQueue)..removeAt(index);
    _syncQueueToAudioService();

    if (!_isManualQueue && _localPlaylist != null) {
      try {
        _localPlaylist!.removeAt(index);
      } catch (e) {
        debugPrint("Error removing from local playlist: $e");
      }
    }

    if (index < _currentIndex) {
      _currentIndex--;
    }

    if (state.valueOrNull != null) {
      state = AsyncValue.data(state.valueOrNull!);
    }
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _currentQueue.length || 
        newIndex < 0 || newIndex >= _currentQueue.length ||
        oldIndex == _currentIndex || newIndex == _currentIndex) {
      return;
    }

    final song = _currentQueue.removeAt(oldIndex);
    _currentQueue.insert(newIndex, song);
    _syncQueueToAudioService();

    if (!_isManualQueue && _localPlaylist != null) {
      try {
        _localPlaylist!.removeAt(oldIndex);
        _localPlaylist!.insert(newIndex, AudioSource.file(
          song.data,
          tag: MediaItem(
            id: song.id.toString(),
            album: song.album ?? "Unknown Album",
            title: song.title,
            artist: song.artist ?? "Unknown Artist",
          ),
        ));
      } catch (e) {
        debugPrint("Error reordering local playlist: $e");
      }
    }

    if (state.valueOrNull != null) {
      state = AsyncValue.data(state.valueOrNull!);
    }
  }

  void skipToNext() {
    final repeatMode = globalAudioHandler.playbackState.value.repeatMode;
    final isShuffle = _player.shuffleModeEnabled;
    if (_isManualQueue) {
      if (isShuffle && _currentQueue.length > 1) {
        _ensureShuffledIndices();
        if (_shuffleIndex < _shuffledIndices.length - 1) {
          _shuffleIndex++;
        } else {
          _shuffleIndex = 0;
        }
        _currentIndex = _shuffledIndices[_shuffleIndex];
        _playCurrentIndex();
      } else if (_currentIndex < _currentQueue.length - 1) {
        _currentIndex++;
        _playCurrentIndex();
      } else if (repeatMode == AudioServiceRepeatMode.all) {
        _currentIndex = 0;
        _playCurrentIndex();
      }
    } else {
      if (_currentIndex < _currentQueue.length - 1) {
        _player.seekToNext();
      } else if (repeatMode == AudioServiceRepeatMode.all) {
        _player.seek(Duration.zero, index: 0);
      }
    }
  }

  void skipToPrevious() {
    final repeatMode = globalAudioHandler.playbackState.value.repeatMode;
    final isShuffle = _player.shuffleModeEnabled;
    if (_isManualQueue) {
      if (_player.position.inSeconds > 3) {
        _player.seek(Duration.zero);
      } else if (isShuffle && _currentQueue.length > 1) {
        _ensureShuffledIndices();
        if (_shuffleIndex > 0) {
          _shuffleIndex--;
        } else {
          _shuffleIndex = _shuffledIndices.length - 1;
        }
        _currentIndex = _shuffledIndices[_shuffleIndex];
        _playCurrentIndex();
      } else if (_currentIndex > 0) {
        _currentIndex--;
        _playCurrentIndex();
      } else if (repeatMode == AudioServiceRepeatMode.all) {
        _currentIndex = _currentQueue.length - 1;
        _playCurrentIndex();
      } else {
        _player.seek(Duration.zero);
      }
    } else {
      if (_player.position.inSeconds > 3) {
        _player.seek(Duration.zero, index: _currentIndex);
      } else if (_player.hasPrevious) {
        _player.seekToPrevious();
      } else if (repeatMode == AudioServiceRepeatMode.all) {
        _player.seek(Duration.zero, index: _currentQueue.length - 1);
      } else {
        _player.seek(Duration.zero, index: 0);
      }
    }
  }

  bool get isPlaying => _player.playing;
  
  List<SongModel> get currentQueue => _currentQueue;
  int get currentIndex => _currentIndex;

  /// Hentikan pemutaran, hapus antrian, dan bersihkan notifikasi (berguna saat logout)
  Future<void> stopPlayback() async {
    await globalAudioHandler.stop();
    await _player.stop();
    _currentQueue = [];
    _shuffledIndices = [];
    _currentIndex = -1;
    _shuffleIndex = -1;
    state = const AsyncValue.data(null);
  }
}
