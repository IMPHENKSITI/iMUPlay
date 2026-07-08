import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../shared/providers/permission_provider.dart';
import '../services/local_music_indexer.dart';

final audioQueryProvider = Provider<OnAudioQuery>((ref) {
  return OnAudioQuery();
});

final localSongsProvider = FutureProvider<List<SongModel>>((ref) async {
  // Wait for permission check
  final hasPermission = await ref.watch(permissionProvider.future);
  
  if (!hasPermission) {
    throw Exception('Permission denied to read local music');
  }

  final audioQuery = ref.watch(audioQueryProvider);
  
  // Fetch all songs
  final songs = await audioQuery.querySongs(
    sortType: null,
    orderType: OrderType.ASC_OR_SMALLER,
    uriType: UriType.EXTERNAL,
    ignoreCase: true,
  );
  
  // Filter out short audio files like ringtones/notifications (e.g., < 30 seconds)
  final validSongs = songs.where((song) => (song.duration ?? 0) > 30000).toList();
  
  // Lakukan Indexing ke Isar di background secara asynchronous tanpa await 
  // agar UI list tidak terblokir
  LocalMusicIndexerService.indexLocalMusic(validSongs);
  
  return validSongs;
});
