import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/online_song_model.dart';
import '../models/artist_profile_model.dart'; // To reuse AlbumModel if needed
import '../../../core/network/dio_client.dart';

class AlbumDetailsModel {
  final AlbumModel album;
  final List<OnlineSongModel> tracks;

  AlbumDetailsModel({
    required this.album,
    required this.tracks,
  });

  factory AlbumDetailsModel.fromJson(Map<String, dynamic> json) {
    final parsedAlbum = AlbumModel.fromJson(json['album'] ?? {});
    final tracksJson = json['tracks'] as List?;
    final parsedTracks = tracksJson?.map((e) {
      final song = OnlineSongModel.fromJson(e);
      return OnlineSongModel(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: parsedAlbum.title,
        thumbnail: song.thumbnail,
        source: song.source,
        streamReference: song.streamReference,
        streamMechanism: song.streamMechanism,
        duration: song.duration,
        isStreamable: song.isStreamable,
      );
    }).toList() ?? [];

    return AlbumDetailsModel(
      album: parsedAlbum,
      tracks: parsedTracks,
    );
  }
}

class AlbumRepository {
  Future<AlbumDetailsModel> getAlbumDetails(String albumId) async {
    try {
      final response = await DioClient.instance.get(
        '/album/${Uri.encodeComponent(albumId)}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data != null) {
          return AlbumDetailsModel.fromJson(data);
        }
      }
      throw Exception('Failed to load album details');
    } catch (e) {
      throw Exception('Failed to load album details: $e');
    }
  }
}

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return AlbumRepository();
});

final albumDetailsProvider = FutureProvider.family<AlbumDetailsModel, String>((ref, albumId) {
  final repository = ref.watch(albumRepositoryProvider);
  return repository.getAlbumDetails(albumId);
});
