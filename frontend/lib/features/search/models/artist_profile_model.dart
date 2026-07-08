import 'online_song_model.dart';

class ArtistInfoModel {
  final String name;
  final String? artwork;
  final String? genre;

  ArtistInfoModel({
    required this.name,
    this.artwork,
    this.genre,
  });

  factory ArtistInfoModel.fromJson(Map<String, dynamic> json) {
    return ArtistInfoModel(
      name: json['name'] ?? 'Unknown Artist',
      artwork: json['artwork'],
      genre: json['genre'],
    );
  }
}

class AlbumModel {
  final String id;
  final String title;
  final String? thumbnail;
  final String year;
  final int trackCount;
  final String type;
  final String? genre;

  AlbumModel({
    required this.id,
    required this.title,
    this.thumbnail,
    required this.year,
    required this.trackCount,
    required this.type,
    this.genre,
  });

  factory AlbumModel.fromJson(Map<String, dynamic> json) {
    return AlbumModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Album',
      thumbnail: json['thumbnail'],
      year: json['year'] ?? '',
      trackCount: json['track_count'] ?? 0,
      type: json['type'] ?? 'album',
      genre: json['genre'],
    );
  }
}

class ArtistProfileModel {
  final ArtistInfoModel artist;
  final List<ArtistInfoModel> relatedArtists;
  final List<OnlineSongModel> topTracks;
  final List<AlbumModel> albums;
  final List<AlbumModel> singles;

  ArtistProfileModel({
    required this.artist,
    this.relatedArtists = const [],
    required this.topTracks,
    required this.albums,
    required this.singles,
  });

  factory ArtistProfileModel.fromJson(Map<String, dynamic> json) {
    return ArtistProfileModel(
      artist: ArtistInfoModel.fromJson(json['artist'] ?? {}),
      relatedArtists: (json['related_artists'] as List?)
              ?.map((e) => ArtistInfoModel.fromJson(e))
              .toList() ??
          [],
      topTracks: (json['top_tracks'] as List?)
              ?.map((e) => OnlineSongModel.fromJson(e))
              .toList() ??
          [],
      albums: (json['albums'] as List?)
              ?.map((e) => AlbumModel.fromJson(e))
              .toList() ??
          [],
      singles: (json['singles'] as List?)
              ?.map((e) => AlbumModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}
