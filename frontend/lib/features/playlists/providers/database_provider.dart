import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../search/models/online_song_model.dart';

// ==========================================
// 1. FAVORITES SYSTEM
// ==========================================

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<int>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<int>> {
  final _box = Hive.box<List>('favorites');

  FavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  void _loadFavorites() {
    final list = _box.get('favorite_ids', defaultValue: <int>[])?.cast<int>();
    state = list ?? [];
  }

  void toggleFavorite(int songId) {
    final currentList = List<int>.from(state);
    if (currentList.contains(songId)) {
      currentList.remove(songId);
    } else {
      currentList.add(songId);
    }
    // Hive requires dynamic list for simple storage, so we cast if needed
    _box.put('favorite_ids', currentList);
    state = currentList;
  }
  
  bool isFavorite(int songId) {
    return state.contains(songId);
  }
}
// ==========================================
// ONLINE FAVORITES SYSTEM
// ==========================================
final onlineFavoritesProvider = StateNotifierProvider<OnlineFavoritesNotifier, List<OnlineSongModel>>((ref) {
  return OnlineFavoritesNotifier();
});

class OnlineFavoritesNotifier extends StateNotifier<List<OnlineSongModel>> {
  final _box = Hive.box<String>('online_playlists');

  OnlineFavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  void _loadFavorites() {
    final jsonString = _box.get('online_favorites_list');
    if (jsonString != null) {
      try {
        final List list = jsonDecode(jsonString);
        state = list.map((e) => OnlineSongModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        state = [];
      }
    } else {
      state = [];
    }
  }

  void toggleFavorite(OnlineSongModel song) {
    final currentList = List<OnlineSongModel>.from(state);
    final index = currentList.indexWhere((s) => s.id == song.id);
    
    if (index != -1) {
      currentList.removeAt(index);
    } else {
      currentList.add(song);
    }
    
    state = currentList;
    _box.put('online_favorites_list', jsonEncode(currentList.map((s) => s.toJson()).toList()));
  }
  
  void addFavorites(List<OnlineSongModel> songs) {
    final currentList = List<OnlineSongModel>.from(state);
    bool changed = false;
    for (final song in songs) {
      if (!currentList.any((s) => s.id == song.id)) {
        currentList.add(song);
        changed = true;
      }
    }
    
    if (changed) {
      state = currentList;
      _box.put('online_favorites_list', jsonEncode(currentList.map((s) => s.toJson()).toList()));
    }
  }
  
  bool isFavorite(String songId) {
    return state.any((s) => s.id == songId);
  }
}

// ==========================================
// 2. PLAYLISTS SYSTEM
// ==========================================

class PlaylistModel {
  final String name;
  final List<int> songIds;
  PlaylistModel({required this.name, required this.songIds});
}

final playlistsProvider = StateNotifierProvider<PlaylistsNotifier, List<PlaylistModel>>((ref) {
  return PlaylistsNotifier();
});

class PlaylistsNotifier extends StateNotifier<List<PlaylistModel>> {
  final _box = Hive.box<List>('playlists');

  PlaylistsNotifier() : super([]) {
    _loadPlaylists();
  }

  void _loadPlaylists() {
    final keys = _box.keys.cast<String>();
    final List<PlaylistModel> loaded = [];
    for (var key in keys) {
      final ids = _box.get(key)?.cast<int>() ?? [];
      loaded.add(PlaylistModel(name: key, songIds: ids));
    }
    // Sort alphabetically
    loaded.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = loaded;
  }

  void createPlaylist(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;
    
    if (!_box.containsKey(trimmedName)) {
      _box.put(trimmedName, <int>[]);
      _loadPlaylists();
    }
  }

  void deletePlaylist(String name) {
    _box.delete(name);
    _loadPlaylists();
  }

  bool isSongInPlaylist(String playlistName, int songId) {
    final playlist = state.firstWhere((p) => p.name == playlistName, orElse: () => PlaylistModel(name: playlistName, songIds: []));
    return playlist.songIds.contains(songId);
  }

  void addSongToPlaylist(String playlistName, int songId) {
    final ids = _box.get(playlistName)?.cast<int>() ?? [];
    final newList = List<int>.from(ids);
    if (!newList.contains(songId)) {
      newList.add(songId);
      _box.put(playlistName, newList);
      _loadPlaylists();
    }
  }

  void removeSongFromPlaylist(String playlistName, int songId) {
    final ids = _box.get(playlistName)?.cast<int>() ?? [];
    final newList = List<int>.from(ids);
    if (newList.contains(songId)) {
      newList.remove(songId);
      _box.put(playlistName, newList);
      _loadPlaylists();
    }
  }
}

// ==========================================
// 3. ONLINE PLAYLISTS SYSTEM
// ==========================================

class OnlinePlaylistModel {
  final String name;
  final List<OnlineSongModel> songs;
  final String? coverUrl; // Network image cover (misal dari album)

  OnlinePlaylistModel({required this.name, required this.songs, this.coverUrl});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'songs': songs.map((s) => s.toJson()).toList(),
      if (coverUrl != null) 'cover_url': coverUrl,
    };
  }

  factory OnlinePlaylistModel.fromJson(Map<String, dynamic> json) {
    return OnlinePlaylistModel(
      name: json['name'] as String,
      songs: (json['songs'] as List).map((s) => OnlineSongModel.fromJson(s as Map<String, dynamic>)).toList(),
      coverUrl: json['cover_url'] as String?,
    );
  }
}

final onlinePlaylistsProvider = StateNotifierProvider<OnlinePlaylistsNotifier, List<OnlinePlaylistModel>>((ref) {
  return OnlinePlaylistsNotifier();
});

class OnlinePlaylistsNotifier extends StateNotifier<List<OnlinePlaylistModel>> {
  final _box = Hive.box<String>('online_playlists');

  OnlinePlaylistsNotifier() : super([]) {
    _loadPlaylists();
  }

  void _loadPlaylists() {
    final jsonStr = _box.get('playlists_data');
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      state = decoded.map((json) => OnlinePlaylistModel.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      state = [];
    }
  }

  void _savePlaylists() {
    final jsonList = state.map((p) => p.toJson()).toList();
    _box.put('playlists_data', jsonEncode(jsonList));
  }

  void createPlaylist(String name, {String? coverUrl}) {
    if (state.any((p) => p.name == name)) return;
    state = [...state, OnlinePlaylistModel(name: name, songs: [], coverUrl: coverUrl)];
    _savePlaylists();
  }

  /// Buat playlist baru langsung beserta lagu-lagunya (untuk album)
  void createPlaylistWithSongs(String name, List<OnlineSongModel> songs, {String? coverUrl}) {
    // Jika sudah ada, tambahkan lagunya saja
    if (state.any((p) => p.name == name)) {
      addSongsToPlaylist(name, songs);
      return;
    }
    state = [...state, OnlinePlaylistModel(name: name, songs: songs, coverUrl: coverUrl)];
    _savePlaylists();
  }

  void deletePlaylist(String name) {
    state = state.where((p) => p.name != name).toList();
    _savePlaylists();
  }

  void addSongToPlaylist(String playlistName, OnlineSongModel song) {
    state = state.map((playlist) {
      if (playlist.name == playlistName) {
        if (!playlist.songs.any((s) => s.id == song.id)) {
          return OnlinePlaylistModel(name: playlist.name, songs: [...playlist.songs, song], coverUrl: playlist.coverUrl);
        }
      }
      return playlist;
    }).toList();
    _savePlaylists();
  }

  /// Tambahkan banyak lagu sekaligus ke playlist (bulk - untuk album)
  void addSongsToPlaylist(String playlistName, List<OnlineSongModel> songs) {
    state = state.map((playlist) {
      if (playlist.name == playlistName) {
        final existing = playlist.songs.map((s) => s.id).toSet();
        final newSongs = songs.where((s) => !existing.contains(s.id)).toList();
        return OnlinePlaylistModel(name: playlist.name, songs: [...playlist.songs, ...newSongs], coverUrl: playlist.coverUrl);
      }
      return playlist;
    }).toList();
    _savePlaylists();
  }

  void removeSongFromPlaylist(String playlistName, String songId) {
    state = state.map((playlist) {
      if (playlist.name == playlistName) {
        return OnlinePlaylistModel(
          name: playlist.name,
          songs: playlist.songs.where((s) => s.id != songId).toList(),
        );
      }
      return playlist;
    }).toList();
    _savePlaylists();
  }

  bool isSongInPlaylist(String playlistName, String songId) {
    final playlist = state.firstWhere(
      (p) => p.name == playlistName,
      orElse: () => OnlinePlaylistModel(name: playlistName, songs: []),
    );
    return playlist.songs.any((s) => s.id == songId);
  }
}

