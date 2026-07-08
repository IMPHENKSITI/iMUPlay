
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Scaffold, AppBar, IconButton, Row, Column, Expanded, Theme, ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors, showDialog, AlertDialog, CircularProgressIndicator, Slider, SliderTheme, Divider, Flexible, Stack, Positioned;
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/audio_player_provider.dart';
import '../../playlists/providers/database_provider.dart';
import '../../playlists/widgets/add_to_playlist_modal.dart';
import '../../search/models/online_song_model.dart';
import 'queue_screen.dart';
import '../../../core/audio/audio_handler.dart';
import 'package:audio_service/audio_service.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final SongModel initialSong;

  const PlayerScreen({super.key, required this.initialSong});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with SingleTickerProviderStateMixin {
  double? _dragPosition;
  bool _isFlipped = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "0:00";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${duration.inHours}:' : ''}$twoDigitMinutes:$twoDigitSeconds";
  }

  /// Pulse animation on button tap
  void _animatePulse() {
    _pulseController.reverse().then((_) => _pulseController.forward());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentSongAsync = ref.watch(audioHandlerProvider);
    final player = ref.watch(audioPlayerProvider);
    final currentSong = currentSongAsync.valueOrNull ?? widget.initialSong;

    // Spotify-inspired colors
    final textPrimary = isDark ? Colors.white : const Color(0xFF191414);
    final textSecondary = isDark ? const Color(0xFFB3B3B3) : const Color(0xFF6B6B6B);
    final accentGreen = const Color(0xFF1DB954); // Spotify green

    // Determine artwork URL for blur background
    final artworkUrl = (currentSong.uri != null && currentSong.uri!.startsWith('http'))
        ? currentSong.uri!
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── LAYER 1: Dynamic Blurred Background ──
            if (artworkUrl != null)
              Positioned.fill(
                child: Image.network(
                  artworkUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            // Blur overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  color: (isDark ? Colors.black : Colors.white).withValues(alpha: isDark ? 0.65 : 0.75),
                ),
              ),
            ),
            // ── LAYER 2: Gradient overlay for readability ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.5, 1.0],
                    colors: isDark
                        ? [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.4),
                            Colors.black.withValues(alpha: 0.85),
                          ]
                        : [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.7),
                          ],
                  ),
                ),
              ),
            ),
            // ── LAYER 3: Actual Content ──
            SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ─── MAIN PLAYER UI ───
              SizedBox(
                // 92% of screen height so the queue peeks out less at the bottom
                height: MediaQuery.of(context).size.height * 0.92,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
            children: [
              // ─── TOP BAR ───
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 32,
                        color: textPrimary,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          'PLAYING FROM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentSong.album ?? 'Your Library',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const QueueScreen(),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.queue_music_rounded,
                            size: 24,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            final isOnline = currentSong.data.startsWith('online:');
                            if (isOnline) {
                              final parts = currentSong.data.split(':');
                              final source = parts[1];
                              final id = parts[2];
                              final streamRef = parts.length > 3 ? parts[3] : null;
                              final onlineSong = OnlineSongModel(
                                id: id,
                                title: currentSong.title,
                                artist: currentSong.artist ?? 'Unknown Artist',
                                duration: 0,
                                source: source,
                                streamReference: streamRef == 'null' ? '' : (streamRef ?? ''),
                                streamMechanism: 'redirect',
                                isStreamable: true,
                                thumbnail: currentSong.uri,
                              );
                              showAddToPlaylistModal(context, ref, onlineSong: onlineSong);
                            } else {
                              showAddToPlaylistModal(context, ref, localSong: currentSong);
                            }                          },
                          child: Icon(
                            Icons.more_vert_rounded,
                            size: 24,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── ALBUM ARTWORK ───
              if (currentSongAsync.hasError)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentSongAsync.error.toString().replaceAll('Exception: ', ''),
                          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                
              Expanded(
                child: Center(
                  child: _buildFlipArtwork(context, currentSong, isDark, textPrimary, textSecondary, accentGreen),
                ),
              ),

              const SizedBox(height: 28),

              // ─── SONG INFO ROW ───

              const SizedBox(height: 28),

              // ─── SONG INFO ROW ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title & Artist (left-aligned like Spotify)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentSong.artist ?? 'Unknown Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Favorite button
                  Consumer(
                    builder: (context, ref, child) {
                      final isOnline = currentSong.data.startsWith('online:');
                      final isFav = isOnline
                          ? ref.watch(onlineFavoritesProvider.notifier).isFavorite(currentSong.data.split(':')[2])
                          : ref.watch(favoritesProvider.notifier).isFavorite(currentSong.id);
                      
                      if (isOnline) {
                        ref.watch(onlineFavoritesProvider);
                      } else {
                        ref.watch(favoritesProvider);
                      }

                      return GestureDetector(
                        onTap: () {
                          if (isOnline) {
                            final parts = currentSong.data.split(':');
                            final source = parts[1];
                            final id = parts[2];
                            final streamRef = parts.length > 3 ? parts[3] : null;
                            final onlineSong = OnlineSongModel(
                              id: id,
                              title: currentSong.title,
                              artist: currentSong.artist ?? 'Unknown Artist',
                              duration: 0,
                              source: source,
                              streamReference: streamRef == 'null' ? '' : (streamRef ?? ''),
                              streamMechanism: 'redirect',
                              isStreamable: true,
                              thumbnail: currentSong.uri,
                            );
                            ref.read(onlineFavoritesProvider.notifier).toggleFavorite(onlineSong);
                          } else {
                            ref.read(favoritesProvider.notifier).toggleFavorite(currentSong.id);
                          }
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            key: ValueKey(isFav),
                            color: isFav ? accentGreen : textSecondary,
                            size: 28,
                          )
                              .animate()
                              .scale(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ─── PROGRESS BAR ───
              StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  return StreamBuilder<Duration?>(
                    stream: player.durationStream,
                    builder: (context, durationSnapshot) {
                      final duration = durationSnapshot.data ?? const Duration(milliseconds: 1);

                      double currentPos = _dragPosition ?? position.inMilliseconds.toDouble();
                      double maxPos = duration.inMilliseconds.toDouble();

                      if (currentPos > maxPos) currentPos = maxPos;
                      if (currentPos < 0) currentPos = 0;

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                              activeTrackColor: isDark ? Colors.white : textPrimary,
                              inactiveTrackColor: isDark ? const Color(0xFF535353) : const Color(0xFFD9D9D9),
                              thumbColor: isDark ? Colors.white : textPrimary,
                              overlayColor: (isDark ? Colors.white : textPrimary).withValues(alpha: 0.1),
                            ),
                            child: Slider(
                              value: currentPos,
                              min: 0,
                              max: maxPos,
                              onChanged: (value) {
                                setState(() {
                                  _dragPosition = value;
                                });
                              },
                              onChangeEnd: (value) {
                                player.seek(Duration(milliseconds: value.toInt()));
                                setState(() {
                                  _dragPosition = null;
                                });
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(Duration(milliseconds: currentPos.toInt())),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 12),

              // ─── PLAYBACK CONTROLS ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Shuffle
                  StreamBuilder<bool>(
                    stream: player.shuffleModeEnabledStream,
                    builder: (context, snapshot) {
                      final isShuffle = snapshot.data ?? false;
                      return GestureDetector(
                        onTap: () => player.setShuffleModeEnabled(!isShuffle),
                        child: Icon(
                          Icons.shuffle_rounded,
                          size: 24,
                          color: isShuffle ? accentGreen : textSecondary,
                        ),
                      );
                    },
                  ),

                  // Previous
                  GestureDetector(
                    onTap: () => ref.read(audioHandlerProvider.notifier).skipToPrevious(),
                    child: Icon(
                      Icons.skip_previous_rounded,
                      size: 40,
                      color: textPrimary,
                    ),
                  ),

                  // Play/Pause (large circle with micro-animation)
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final isPlaying = playerState?.playing ?? false;
                      final isBuffering = playerState?.processingState == ProcessingState.loading || 
                                          playerState?.processingState == ProcessingState.buffering;
                      
                      return ScaleTransition(
                        scale: _pulseController,
                        child: GestureDetector(
                          onTap: () {
                            _animatePulse();
                            if (isPlaying) {
                              ref.read(audioHandlerProvider.notifier).pause();
                            } else {
                              ref.read(audioHandlerProvider.notifier).play();
                            }
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white : textPrimary,
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark ? Colors.white : textPrimary).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: isBuffering 
                              ? Padding(
                                  padding: const EdgeInsets.all(18.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3, 
                                    color: isDark ? textPrimary : Colors.white,
                                  ),
                                )
                              : Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 38,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Next
                  GestureDetector(
                    onTap: () => ref.read(audioHandlerProvider.notifier).skipToNext(),
                    child: Icon(
                      Icons.skip_next_rounded,
                      size: 40,
                      color: textPrimary,
                    ),
                  ),

                  // Repeat
                  StreamBuilder<PlaybackState>(
                    stream: globalAudioHandler.playbackState,
                    builder: (context, snapshot) {
                      final repeatMode = snapshot.data?.repeatMode ?? AudioServiceRepeatMode.none;
                      IconData icon = Icons.repeat_rounded;
                      Color color = textSecondary;

                      if (repeatMode == AudioServiceRepeatMode.all) {
                        color = accentGreen;
                      } else if (repeatMode == AudioServiceRepeatMode.one) {
                        icon = Icons.repeat_one_rounded;
                        color = accentGreen;
                      }

                      return GestureDetector(
                        onTap: () {
                          globalAudioHandler.customAction('cycle_repeat');
                        },
                        child: Icon(icon, size: 24, color: color),
                      );
                    },
                  ),
                ],
              ),

                    ],
                  ),
                ),
              ),
            ), // close SizedBox
              
              // ─── SWIPE-UP QUEUE SECTION ───
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Consumer(
                      builder: (context, ref, child) {
                        ref.watch(audioHandlerProvider); // force rebuild when queue is updated
                        final queue = ref.watch(audioHandlerProvider.notifier).currentQueue;
                        final currentIndex = ref.watch(audioHandlerProvider.notifier).currentIndex;
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Handle Pill
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 16, bottom: 12),
                                width: 48,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: textSecondary.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              child: Text(
                                'Antrean Berikutnya',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            if (queue.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.queue_music_rounded, size: 48, color: textSecondary.withValues(alpha: 0.5)),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Antrean kosong',
                                        style: TextStyle(color: textSecondary, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 40, top: 8),
                                itemCount: queue.length,
                                itemBuilder: (context, index) {
                                  final song = queue[index];
                                  final isPlaying = index == currentIndex;
                                  final isOnline = song.data.startsWith('online:');
                                  
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        ref.read(audioHandlerProvider.notifier).seek(Duration.zero, index: index);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 52,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10),
                                                color: isDark ? const Color(0xFF282828) : const Color(0xFFF0F0F0),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.1),
                                                    blurRadius: 5,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  isOnline
                                                      ? Image.network(
                                                          song.uri ?? '', 
                                                          fit: BoxFit.cover, 
                                                          errorBuilder: (_, _, _) => Icon(Icons.music_note_rounded, color: textSecondary)
                                                        )
                                                      : QueryArtworkWidget(
                                                          id: song.id,
                                                          type: ArtworkType.AUDIO,
                                                          artworkBorder: BorderRadius.zero,
                                                          nullArtworkWidget: Icon(Icons.music_note_rounded, color: textSecondary),
                                                        ),
                                                  if (isPlaying)
                                                    Container(
                                                      color: Colors.black.withValues(alpha: 0.5),
                                                      child: Icon(Icons.equalizer_rounded, color: accentGreen, size: 28),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    song.title,
                                                    style: TextStyle(
                                                      color: isPlaying ? accentGreen : textPrimary,
                                                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w600,
                                                      fontSize: 16,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    song.artist ?? 'Unknown Artist',
                                                    style: TextStyle(
                                                      color: textSecondary,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!isPlaying)
                                              GestureDetector(
                                                onTap: () {
                                                  ref.read(audioHandlerProvider.notifier).removeFromQueue(index);
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.all(8.0),
                                                  child: Icon(Icons.remove_circle_outline_rounded, color: Colors.red.withValues(alpha: 0.7), size: 24),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),  // close SingleChildScrollView
          ],  // close Stack children
        ),  // close Stack
      ),  // close Material
    );  // close Scaffold
  }

  Widget _buildPlaceholderArt(Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.7),
            accentColor.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.music_note_rounded, size: 80, color: Colors.white),
      ),
    );
  }

  Duration _getDuration(dynamic song) {
    if (song == null || song.duration == null) return Duration.zero;
    if (song.duration is Duration) return song.duration;
    if (song.duration is int) {
      // on_audio_query returns milliseconds (usually > 10000 for songs), 
      // while our Online API returns seconds.
      if (song.duration > 10000) {
        return Duration(milliseconds: song.duration);
      }
      return Duration(seconds: song.duration);
    }
    return Duration.zero;
  }

  String _getTitle(dynamic song) => song.title ?? 'Unknown Title';
  String _getArtist(dynamic song) => song.artist ?? 'Unknown Artist';
  String _getAlbum(dynamic song) => song.album ?? 'Unknown Album';

  Widget _buildFlipArtwork(BuildContext context, dynamic currentSong, bool isDark, Color textPrimary, Color textSecondary, Color accentGreen) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isFlipped = !_isFlipped;
        });
      },
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0, end: _isFlipped ? 180 : 0),
        duration: const Duration(milliseconds: 500),
        builder: (context, double value, child) {
          bool isBack = value >= 90;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(value * 3.1415927 / 180),
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(3.1415927),
                    child: _buildMetadataCard(currentSong, isDark, textPrimary, textSecondary),
                  )
                : _buildFrontArtwork(currentSong, isDark, accentGreen),
          );
        },
      ),
    );
  }

  Widget _buildFrontArtwork(dynamic currentSong, bool isDark, Color accentGreen) {
    return Hero(
      tag: 'artwork_${currentSong.id}',
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
                blurRadius: 40,
                offset: const Offset(0, 20),
                spreadRadius: 5,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: currentSong.uri != null && currentSong.uri!.startsWith('http')
              ? Image.network(
                  currentSong.uri!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderArt(accentGreen),
                )
              : QueryArtworkWidget(
                  id: currentSong.id,
                  type: ArtworkType.AUDIO,
                  artworkQuality: FilterQuality.high,
                  artworkBorder: BorderRadius.circular(8),
                  size: 600,
                  nullArtworkWidget: _buildPlaceholderArt(accentGreen),
                ),
        ),
      ),
    );
  }

  Widget _buildMetadataCard(dynamic song, bool isDark, Color textPrimary, Color textSecondary) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.25),
              blurRadius: 40,
              offset: const Offset(0, 20),
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TRACK INFO',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildMetaRow('Judul', _getTitle(song), textPrimary, textSecondary),
            _buildMetaRow('Artis', _getArtist(song), textPrimary, textSecondary),
            _buildMetaRow('Album', _getAlbum(song), textPrimary, textSecondary),
            StreamBuilder<Duration?>(
              stream: ref.watch(audioPlayerProvider).durationStream,
              builder: (context, snapshot) {
                final duration = snapshot.data ?? _getDuration(song);
                return _buildMetaRow('Durasi', _formatDuration(duration), textPrimary, textSecondary);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
