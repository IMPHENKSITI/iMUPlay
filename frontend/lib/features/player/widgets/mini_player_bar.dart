import 'dart:ui';
import 'package:flutter/material.dart' hide Scaffold, AppBar, IconButton, Positioned, Stack, Row, Column, Expanded, Theme, ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors, showDialog, AlertDialog, CircularProgressIndicator, Slider, SliderTheme, Divider, Flexible, TextField;
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/audio_player_provider.dart';
import '../screens/player_screen.dart';
import '../../../shared/theme/app_colors.dart';

class MiniPlayerPlaceholder extends ConsumerStatefulWidget {
  const MiniPlayerPlaceholder({super.key});

  @override
  ConsumerState<MiniPlayerPlaceholder> createState() => _MiniPlayerPlaceholderState();
}

class _MiniPlayerPlaceholderState extends ConsumerState<MiniPlayerPlaceholder> with WidgetsBindingObserver {
  bool _dismissed = false;
  String? _lastSongId; // track song changes to re-show player

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Jika user kembali ke app (misal lewat notifikasi), munculkan lagi mini player
      if (_dismissed && mounted) {
        setState(() => _dismissed = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSongAsync = ref.watch(audioHandlerProvider);
    final player = ref.watch(audioPlayerProvider);

    return currentSongAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
      data: (song) {
        if (song == null) {
          // Reset dismissed state when no song
          if (_dismissed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _dismissed = false);
            });
          }
          return const SizedBox.shrink();
        }

        // Re-show if song changed while dismissed
        if (_lastSongId != song.id.toString()) {
          if (_dismissed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _dismissed = false);
            });
          }
          _lastSongId = song.id.toString();
        }

        if (_dismissed) return const SizedBox.shrink();

        return _buildMiniPlayer(context, ref, song, player, isDark);
      },
    );
  }

  Widget _buildMiniPlayer(
    BuildContext context,
    WidgetRef ref,
    dynamic song,
    dynamic player,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            barrierColor: Colors.black.withValues(alpha: 0.5),
            builder: (context) => PlayerScreen(initialSong: song),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                // Gradient tint subtle di background
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          AppColors.darkStart.withValues(alpha: 0.18),
                          AppColors.darkEnd.withValues(alpha: 0.12),
                        ]
                      : [
                          AppColors.lightStart.withValues(alpha: 0.22),
                          AppColors.lightEnd.withValues(alpha: 0.15),
                        ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.glassBorder(isDark: isDark),
                  width: 0.8,
                ),
                boxShadow: [
                  AppColors.coloredShadow(isDark: isDark, opacity: 0.2),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),

                  // ── Artwork ──────────────────────────────────────────
                  Hero(
                    tag: 'artwork_${song.id}',
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientDiagonal(isDark: isDark),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [AppColors.coloredShadow(isDark: isDark, opacity: 0.35)],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: song.uri != null && song.uri!.startsWith('http')
                          ? Image.network(
                              song.uri!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.music_note_rounded, color: Colors.white),
                            )
                          : QueryArtworkWidget(
                              id: song.id,
                              type: ArtworkType.AUDIO,
                              artworkBorder: BorderRadius.circular(10),
                              nullArtworkWidget:
                                  const Icon(Icons.music_note_rounded, color: Colors.white),
                            ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ── Title & Artist ────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          song.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.2,
                            color: AppColors.textPrimary(isDark: isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist ?? 'Unknown Artist',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            color: AppColors.textSecondary(isDark: isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // ── Play/Pause ────────────────────────────────────────
                  StreamBuilder<bool>(
                    stream: player.playingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return GestureDetector(
                        onTap: () {
                          if (isPlaying) {
                            ref.read(audioHandlerProvider.notifier).pause();
                          } else {
                            ref.read(audioHandlerProvider.notifier).play();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ShaderMask(
                            shaderCallback: (b) => AppColors.gradient(isDark: isDark)
                                .createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
                            child: Icon(
                              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scale(
                                duration: const Duration(milliseconds: 1200),
                                begin: const Offset(1, 1),
                                end: const Offset(1.04, 1.04),
                                curve: Curves.easeInOut,
                              ),
                        ),
                      );
                    },
                  ),

                  // ── Skip Next ─────────────────────────────────────────
                  GestureDetector(
                    onTap: () => ref.read(audioHandlerProvider.notifier).skipToNext(),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, right: 6),
                      child: Icon(
                        Icons.skip_next_rounded,
                        size: 28,
                        color: AppColors.textSecondary(isDark: isDark),
                      ),
                    ),
                  ),

                  // ── Dismiss (X) ───────────────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _dismissed = true),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary(isDark: isDark).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.textSecondary(isDark: isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate()
          .slideY(begin: 1.0, end: 0.0, duration: 320.ms, curve: Curves.easeOut)
          .fadeIn(duration: 280.ms),
    );
  }
}