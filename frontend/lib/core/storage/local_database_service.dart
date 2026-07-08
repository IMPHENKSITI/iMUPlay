import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import '../../shared/models/local_database_schemas.dart';

class LocalDatabaseService {
  static late Isar localDb;

  static Future<void> init() async {
    final dir = await path_provider.getApplicationDocumentsDirectory();
    localDb = await Isar.open(
      [
        LocalArtistSchema,
        LocalAlbumSchema,
        LocalTrackSchema,
        QueueItemSchema,
        PlaylistModelSchema,
        PlayHistorySchema,
      ],
      directory: dir.path,
    );
  }
}
