// ignore_for_file: experimental_member_use
import 'package:isar/isar.dart';

part 'local_database_schemas.g.dart';

// --- RELATIONAL LOCAL MUSIC INDEXING ---

@collection
class LocalArtist {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  @Backlink(to: 'artist')
  final tracks = IsarLinks<LocalTrack>();
}

@collection
class LocalAlbum {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String name;

  late String? artistName;

  @Backlink(to: 'album')
  final tracks = IsarLinks<LocalTrack>();
}

@collection
class LocalTrack {
  Id id = Isar.autoIncrement; // Bisa menggunakan ID bawaan file (MediaStore ID)
  
  @Index(caseSensitive: false)
  late String title;

  // Relasi
  final artist = IsarLink<LocalArtist>();
  final album = IsarLink<LocalAlbum>();

  @Index(caseSensitive: false)
  String? genre;

  @Index()
  int? year;

  late String dataPath; // Lokasi file .mp3 / .m4a lokal
  late int duration;
  late int size;
  
  String? artworkUrl; // URL Thumbnail atau path lokal
}

// --- QUEUE & HISTORY (UNIFIED: ONLINE + LOCAL) ---

@collection
class QueueItem {
  Id id = Isar.autoIncrement;
  
  late String trackId;
  late String title;
  late String artist;
  late String source;        // 'youtube', 'audius', 'jamendo', 'local'
  late String streamReference;
  late String streamMechanism;
  String? thumbnailUrl;
  late int duration;
  late int position;
  late bool isLocal;
  String? localPath;
}

@collection
class PlaylistModel {
  Id id = Isar.autoIncrement;
  late String name;
  late DateTime createdAt;
  
  final tracks = IsarLinks<QueueItem>();
}

@collection
class PlayHistory {
  Id id = Isar.autoIncrement;
  
  late String trackId;
  late String title;
  late String artist;
  late String source;
  String? thumbnailUrl;
  
  late int duration;
  late bool isLocal;
  String? dataPath;

  @Index()
  late DateTime playedAt;
  late int durationPlayed;
}
