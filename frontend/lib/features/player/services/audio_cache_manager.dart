import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class CacheMetadata {
  final int lastPlayedMs;
  final String criteria;

  CacheMetadata({required this.lastPlayedMs, required this.criteria});

  Map<String, dynamic> toJson() => {
        'lastPlayedMs': lastPlayedMs,
        'criteria': criteria,
      };

  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    return CacheMetadata(
      lastPlayedMs: json['lastPlayedMs'] as int,
      criteria: json['criteria'] as String,
    );
  }
}

class AudioCacheManager {
  static const int _maxCacheSizeBytes = 2147483648; // 2 GB

  static Box<String> get _box => Hive.box<String>('cache_metadata');

  static Future<Directory> getCacheDirectory() async {
    final docDir = await getApplicationSupportDirectory();
    final cacheDir = Directory('${docDir.path}/audio_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  static String _getSafeRef(String streamRef) {
    return streamRef.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  static Future<String> getCacheFilePath(String streamRef) async {
    final dir = await getCacheDirectory();
    final safeRef = _getSafeRef(streamRef);
    return '${dir.path}/$safeRef.mp3';
  }

  static Future<String> getArtworkCacheFilePath(int songId) async {
    final dir = await getCacheDirectory();
    return '${dir.path}/artwork_$songId.jpg';
  }

  static Future<String?> cacheArtwork(int songId, Uint8List bytes) async {
    try {
      final path = await getArtworkCacheFilePath(songId);
      final file = File(path);
      if (!await file.exists()) {
        await file.writeAsBytes(bytes);
      }
      return path;
    } catch (e) {
      debugPrint("Error caching artwork: $e");
      return null;
    }
  }

  static Future<void> cacheOrUpdateSong(String streamRef, String criteria) async {
    final metadata = CacheMetadata(
      lastPlayedMs: DateTime.now().millisecondsSinceEpoch,
      criteria: criteria,
    );
    final safeRef = _getSafeRef(streamRef);
    await _box.put(safeRef, jsonEncode(metadata.toJson()));
    _cleanupOldCachesIfNeeded();
  }

  static Future<void> _cleanupOldCachesIfNeeded() async {
    try {
      final cacheDir = await getCacheDirectory();
      final List<FileSystemEntity> files = await cacheDir.list().toList();
      
      int totalSize = 0;
      final Map<String, File> fileMap = {};
      final now = DateTime.now().millisecondsSinceEpoch;

      for (var entity in files) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.last;
          
          // Jangan hapus file artwork atau file non-mp3 yang mungkin masih terpakai sementara
          if (fileName.startsWith('artwork_') || !fileName.endsWith('.mp3')) {
             if (fileName.endsWith('.tmp')) {
                // Hapus .tmp yatim piatu (orphan temp files)
                try { await entity.delete(); } catch (_) {}
             }
             continue;
          }

          final basename = fileName.replaceAll('.mp3', '');
          
          final jsonString = _box.get(basename);
          CacheMetadata? metadata;
          if (jsonString != null) {
            try {
              metadata = CacheMetadata.fromJson(jsonDecode(jsonString));
            } catch (e) {
              metadata = null;
            }
          }

          // 1. TTL SWEEPER
          bool shouldDelete = false;
          if (metadata != null) {
            final diffMs = now - metadata.lastPlayedMs;
            final daysSincePlayed = diffMs / (1000 * 60 * 60 * 24);
            
            if (metadata.criteria == 'search' && daysSincePlayed > 3) {
              shouldDelete = true;
            } else if (metadata.criteria == 'playlist' && daysSincePlayed > 14) {
              shouldDelete = true;
            } else if (metadata.criteria == 'favorite' && daysSincePlayed > 30) {
              shouldDelete = true;
            }
          } else {
            // Unregistered file -> delete
            shouldDelete = true;
          }

          if (shouldDelete) {
            try {
              await entity.delete();
              await _box.delete(basename);
            } catch (e) {
              // ignore
            }
          } else {
            final stat = await entity.stat();
            totalSize += stat.size;
            fileMap[basename] = entity;
          }
        }
      }

      // 2. LRU 2GB SWEEPER
      if (totalSize > _maxCacheSizeBytes) {
        debugPrint('Cache size ($totalSize bytes) exceeded limit. Cleaning up...');
        
        final entries = fileMap.entries.toList();
        entries.sort((a, b) {
          final jsonA = _box.get(a.key);
          final jsonB = _box.get(b.key);
          final timeA = jsonA != null ? CacheMetadata.fromJson(jsonDecode(jsonA)).lastPlayedMs : 0;
          final timeB = jsonB != null ? CacheMetadata.fromJson(jsonDecode(jsonB)).lastPlayedMs : 0;
          return timeA.compareTo(timeB);
        });

        int currentSize = totalSize;
        final targetSize = _maxCacheSizeBytes * 0.9; // 1.8 GB

        for (var entry in entries) {
          if (currentSize <= targetSize) break;

          final file = entry.value;
          final stat = await file.stat();
          try {
            await file.delete();
            await _box.delete(entry.key);
            currentSize -= stat.size;
          } catch (e) {
            // ignore
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up cache: $e');
    }
  }
}
