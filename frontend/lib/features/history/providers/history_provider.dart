import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../core/storage/local_database_service.dart';
import '../../../shared/models/local_database_schemas.dart';

final historyProvider = StateNotifierProvider<HistoryNotifier, List<SongModel>>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<List<SongModel>> {
  static const int _maxHistory = 100;
  final Isar _localDb = LocalDatabaseService.localDb;

  HistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final histories = await _localDb.playHistorys.where().sortByPlayedAtDesc().findAll();
    
    state = histories.map((h) => _toSongModel(h)).toList();
  }

  Future<void> addSongToHistory(SongModel song) async {
    final newHistory = _fromSongModel(song);
    
    await _localDb.writeTxn(() async {
      // Hapus jika sudah ada (by trackId) supaya bisa dipindah ke atas
      await _localDb.playHistorys.filter().trackIdEqualTo(newHistory.trackId).deleteAll();
      
      // Hitung total history sekarang
      final count = await _localDb.playHistorys.count();
      if (count >= _maxHistory) {
        // Hapus semua yang berlebih (paling lama)
        final excess = count - _maxHistory + 1;
        final oldestItems = await _localDb.playHistorys.where().sortByPlayedAt().limit(excess).findAll();
        final oldestIds = oldestItems.map((e) => e.id).toList();
        await _localDb.playHistorys.deleteAll(oldestIds);
      }
      
      // Simpan history baru
      await _localDb.playHistorys.put(newHistory);
    });
    
    await _loadHistory();
  }
  
  Future<void> clearHistory() async {
    await _localDb.writeTxn(() async {
      await _localDb.playHistorys.clear();
    });
    state = [];
  }

  SongModel _toSongModel(PlayHistory h) {
    return SongModel({
      "_id": h.isLocal ? int.tryParse(h.trackId) ?? 0 : h.trackId.hashCode,
      "title": h.title,
      "artist": h.artist,
      "duration": h.duration,
      "data": h.dataPath ?? h.thumbnailUrl ?? '', // Gunakan data untuk path/url
      "isLocal": h.isLocal, // Ini custom property, tapi SongModel pake map
      "_data": h.dataPath, // on_audio_query data path
    });
  }

  PlayHistory _fromSongModel(SongModel s) {
    // Bedakan local vs online berdasarkan adanya flag isLocal atau dari format string _id
    final isLocal = (s.getMap['isLocal'] == true) || !s.data.startsWith('http');
    
    return PlayHistory()
      ..trackId = s.id.toString()
      ..title = s.title
      ..artist = s.artist ?? 'Unknown Artist'
      ..source = isLocal ? 'local' : 'online'
      ..thumbnailUrl = isLocal ? null : s.data // data berisi thumbnail kalau online
      ..dataPath = isLocal ? s.data : null
      ..duration = s.duration ?? 0
      ..isLocal = isLocal
      ..playedAt = DateTime.now()
      ..durationPlayed = 0;
  }
}
