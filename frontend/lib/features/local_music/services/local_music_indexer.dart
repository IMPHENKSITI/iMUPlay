import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter/foundation.dart';
import '../../../core/storage/local_database_service.dart';
import '../../../shared/models/local_database_schemas.dart';

class LocalMusicIndexerService {
  static Future<void> indexLocalMusic(List<SongModel> songs) async {
    final localDb = LocalDatabaseService.localDb;
    
    // Mengecek apakah jumlah lagu di HP sama dengan di Isar
    // Jika sama, asumsikan tidak ada perubahan (bisa diperbaiki dengan cek lastModified jika ada)
    final existingCount = await localDb.localTracks.count();
    if (existingCount == songs.length) {
      debugPrint("LocalMusicIndexer: Tracks count match. Skipping full indexing.");
      return; 
    }
    
    debugPrint("LocalMusicIndexer: Starting to index ${songs.length} songs into Local DB...");
    
    await localDb.writeTxn(() async {
      // Bersihkan data lama
      await localDb.localTracks.clear();
      await localDb.localArtists.clear();
      await localDb.localAlbums.clear();
      
      final Map<String, LocalArtist> artistMap = {};
      final Map<String, LocalAlbum> albumMap = {};

      for (var song in songs) {
        // --- 1. Proses Artist ---
        final artistName = song.artist ?? 'Unknown Artist';
        if (!artistMap.containsKey(artistName)) {
          final artist = LocalArtist()..name = artistName;
          await localDb.localArtists.put(artist); // Simpan untuk dapat ID
          artistMap[artistName] = artist;
        }
        
        // --- 2. Proses Album ---
        final albumName = song.album ?? 'Unknown Album';
        final albumKey = '$artistName-$albumName'; // Composite key sementara di memori
        if (!albumMap.containsKey(albumKey)) {
          final album = LocalAlbum()
            ..name = albumName
            ..artistName = artistName;
          await localDb.localAlbums.put(album); // Simpan untuk dapat ID
          albumMap[albumKey] = album;
        }
        
        // --- 3. Proses Track ---
        final track = LocalTrack()
          ..id = song.id // Gunakan ID bawaan MediaStore agar persisten
          ..title = song.title
          ..genre = song.genre
          ..dataPath = song.data
          ..duration = song.duration ?? 0
          ..size = song.size;
          
        track.artist.value = artistMap[artistName];
        track.album.value = albumMap[albumKey];
        
        await localDb.localTracks.put(track);
        await track.artist.save();
        await track.album.save();
      }
    });
    
    debugPrint("LocalMusicIndexer: Indexing completed successfully.");
  }
}
