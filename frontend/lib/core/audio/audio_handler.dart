import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

late MyAudioHandler globalAudioHandler;

Future<void> initAudioService() async {
  globalAudioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.music_player.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler {
  final AudioPlayer player = AudioPlayer(
    handleInterruptions: false,
    androidApplyAudioAttributes: false,
    handleAudioSessionActivation: false,
  );
  
  // Callbacks for next/previous to be handled by AudioPlayerProvider
  void Function()? onSkipToNextCb;
  void Function()? onSkipToPreviousCb;

  MyAudioHandler() {
    player.playbackEventStream.listen((PlaybackEvent event) {
      final playing = player.playing;
      final repeatMode = playbackState.value.repeatMode;
      
      MediaControl repeatControl;
      if (repeatMode == AudioServiceRepeatMode.none) {
        repeatControl = const MediaControl(
          androidIcon: 'drawable/ic_repeat_off',
          label: 'Repeat Off',
          action: MediaAction.custom,
          customAction: CustomMediaAction(name: 'cycle_repeat'),
        );
      } else if (repeatMode == AudioServiceRepeatMode.all) {
        repeatControl = const MediaControl(
          androidIcon: 'drawable/ic_repeat',
          label: 'Repeat All',
          action: MediaAction.custom,
          customAction: CustomMediaAction(name: 'cycle_repeat'),
        );
      } else {
        repeatControl = const MediaControl(
          androidIcon: 'drawable/ic_repeat_one',
          label: 'Repeat One',
          action: MediaAction.custom,
          customAction: CustomMediaAction(name: 'cycle_repeat'),
        );
      }

      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.stop,
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          repeatControl,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.stop,
          MediaAction.skipToPrevious,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.skipToNext,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [1, 2, 3], // Prev, Play/Pause, Next
        processingState: const {
          ProcessingState.idle: AudioProcessingState.buffering, // Map idle to buffering to prevent notification disappearance during track change
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: event.currentIndex,
      ));
    });

    // Perbarui durasi lagu secara dinamis saat lagu berhasil dimuat
    player.durationStream.listen((duration) {
      if (mediaItem.value != null && duration != null && duration.inMilliseconds > 0) {
        // Hanya timpa durasi jika MediaItem saat ini belum memiliki durasi yang valid
        final currentDuration = mediaItem.value!.duration;
        if (currentDuration == null || currentDuration.inMilliseconds == 0) {
          mediaItem.add(mediaItem.value!.copyWith(duration: duration));
        }
      }
    });
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'cycle_repeat') {
      final currentMode = playbackState.value.repeatMode;
      AudioServiceRepeatMode nextMode;
      if (currentMode == AudioServiceRepeatMode.none) {
        nextMode = AudioServiceRepeatMode.all;
      } else if (currentMode == AudioServiceRepeatMode.all) {
        nextMode = AudioServiceRepeatMode.one;
      } else {
        nextMode = AudioServiceRepeatMode.none;
      }
      
      MediaControl repeatControl;
      if (nextMode == AudioServiceRepeatMode.none) {
        repeatControl = const MediaControl(
          androidIcon: 'drawable/ic_repeat_off',
          label: 'Repeat Off',
          action: MediaAction.custom,
          customAction: CustomMediaAction(name: 'cycle_repeat'),
        );
      } else if (nextMode == AudioServiceRepeatMode.all) {
        repeatControl = const MediaControl(
          androidIcon: 'drawable/ic_repeat',
          label: 'Repeat All',
          action: MediaAction.custom,
          customAction: CustomMediaAction(name: 'cycle_repeat'),
        );
      } else {
        repeatControl = const MediaControl(
          androidIcon: 'drawable/ic_repeat_one',
          label: 'Repeat One',
          action: MediaAction.custom,
          customAction: CustomMediaAction(name: 'cycle_repeat'),
        );
      }

      final playing = playbackState.value.playing;

      playbackState.add(playbackState.value.copyWith(
        repeatMode: nextMode,
        controls: [
          MediaControl.stop,
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          repeatControl,
        ],
      ));
    }
    return super.customAction(name, extras);
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    // Membantu Xiaomi / OS Android menampilkan info riwayat lagu (Media Resumption)
    return mediaItem.value;
  }

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId, [Map<String, dynamic>? options]) async {
    // Mengizinkan OS (terutama Xiaomi) untuk melihat riwayat antrean lagu
    return queue.value;
  }

  @override
  Future<void> play() async {
    final session = await AudioSession.instance;
    await session.setActive(true);
    return player.play();
  }

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (onSkipToNextCb != null) {
      onSkipToNextCb!();
    } else {
      await player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPreviousCb != null) {
      onSkipToPreviousCb!();
    } else {
      await player.seekToPrevious();
    }
  }
}
