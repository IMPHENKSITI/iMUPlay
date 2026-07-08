import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AudioSessionManager {
  static const String _boxName = 'settings';
  static const String _focusKey = 'audio_focus_preference';

  /// 0 = Abaikan Aplikasi Lain (hanya jeda saat telepon)
  /// 1 = Hormati Aplikasi Lain (jeda otomatis saat aplikasi lain bersuara)
  static int get focusPreference {
    final box = Hive.box<String>(_boxName);
    return int.tryParse(box.get(_focusKey) ?? '0') ?? 0;
  }

  static Future<void> setFocusPreference(int value) async {
    final box = Hive.box<String>(_boxName);
    await box.put(_focusKey, value.toString());
    await configureSession();
  }

  static Future<void> configureSession() async {
    try {
      final session = await AudioSession.instance;
      
      if (focusPreference == 0) {
        // Abaikan aplikasi lain, hanya jeda saat ada telepon
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
            flags: AndroidAudioFlags.none,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck, // Ducking (mengecil) saat ada notifikasi
          androidWillPauseWhenDucked: false, 
        ));
      } else {
        // Hormati aplikasi lain (jeda otomatis saat aplikasi lain bersuara)
        await session.configure(const AudioSessionConfiguration.music());
      }
    } catch (e) {
      debugPrint("Gagal mengkonfigurasi AudioSession: $e");
    }
  }
}
