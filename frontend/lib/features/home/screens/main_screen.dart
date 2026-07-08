import 'dart:ui';
import 'package:flutter/material.dart' hide Scaffold, AppBar, IconButton, Positioned, Stack, Divider, Row, Column, Expanded, Colors, Theme, ThemeData, TextField, ListTile, CircularProgressIndicator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../local_music/providers/audio_query_provider.dart';
import '../../player/providers/audio_player_provider.dart';
import '../../player/widgets/mini_player_bar.dart';
import '../../playlists/screens/playlists_screen.dart';
import '../../playlists/widgets/add_to_playlist_modal.dart';
import '../../search/screens/search_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../auth/auth_gate.dart';
import '../../auth/cloud_sync_provider.dart';
import '../../../core/network/auth_provider.dart';
import '../../../shared/theme/app_colors.dart';

// ─── Local Music Tab ──────────────────────────────────────────────────────────
class LocalMusicScreen extends ConsumerWidget {
  const LocalMusicScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsyncValue = ref.watch(localSongsProvider);

    return songsAsyncValue.when(
      loading: () => _buildShimmerList(context),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat musik:\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: () => ref.refresh(localSongsProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
      data: (songs) {
        if (songs.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF282828) : const Color(0xFFF0F0F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.music_off_rounded,
                      size: 40,
                      color: Theme.of(context).colorScheme.foreground.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada musik ditemukan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cek permission penyimpanan atau tambahkan file MP3 ke HP ini',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.foreground.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 140),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return InkWell(
              onTap: () {
                ref.read(audioHandlerProvider.notifier).playSong(song, queue: songs);
              },
              borderRadius: BorderRadius.circular(12),
              splashColor: AppColors.primary(isDark: isDark).withValues(alpha: 0.1),
              highlightColor: AppColors.primary(isDark: isDark).withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Hero(
                      tag: 'artwork_${song.id}',
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientDiagonal(isDark: isDark),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [AppColors.coloredShadow(isDark: isDark, opacity: 0.25)],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: song.uri != null && song.uri!.startsWith('http')
                            ? Image.network(
                                song.uri!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.music_note, color: Colors.white),
                              )
                            : QueryArtworkWidget(
                                id: song.id,
                                type: ArtworkType.AUDIO,
                                artworkBorder: BorderRadius.circular(8),
                                nullArtworkWidget:
                                    const Icon(Icons.music_note, color: Colors.white),
                              ),
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
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              height: 1.3,
                              color: AppColors.textPrimary(isDark: isDark),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song.artist ?? 'Unknown Artist',
                            style: TextStyle(
                              color: AppColors.textSecondary(isDark: isDark),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton.ghost(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        showAddToPlaylistModal(context, ref, localSong: song);
                      },
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                )
                .slideY(
                  begin: 0.1,
                  end: 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  delay: Duration(milliseconds: 40 * (index % 10)),
                );
          },
        );
      },
    );
  }

  Widget _buildShimmerList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmerColor = isDark ? const Color(0xFF282828) : const Color(0xFFE8E8E8);

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 140),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 180,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .fadeIn(duration: const Duration(milliseconds: 800))
            .slideY(
              begin: 0,
              end: 0.02,
              duration: const Duration(milliseconds: 800),
            );
      },
    );
  }
}

// ─── Main Screen ─────────────────────────────────────────────────────────────
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  Future<void> _onTabTapped(int index) async {
    // Search (index 1) requires login
    if (index == 1) {
      final isLoggedIn = ref.read(authProvider).isLoggedIn;
      if (!isLoggedIn) {
        final loggedIn = await showAuthGate(context);
        if (!loggedIn) return;
      }
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(cloudSyncProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final tabNames = ['Local Music', 'Search', 'Playlists'];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F7),
      child: Stack(
        children: [
          // ── Main content (padded below AppBar and NavBar) ──
          Positioned.fill(
            top: MediaQuery.of(context).padding.top + 56, // below fixed AppBar
            bottom: 64,                                    // above NavBar
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: IndexedStack(
                key: ValueKey(_currentIndex),
                index: _currentIndex,
                children: const [
                  LocalMusicScreen(),
                  SearchScreen(),
                  PlaylistsScreen(),
                ],
              ),
            ),
          ),

          // ── Fixed AppBar (Glass) ──────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassAppBar(isDark, auth, tabNames),
          ),

          // ── Mini Player ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 72, // sits above NavBar
            child: const MiniPlayerPlaceholder(),
          ),

          // ── Fixed Bottom NavBar (Glass) ───────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildGlassNavBar(isDark),
          ),
        ],
      ),
    );
  }

  // ── Premium Colored Glass AppBar ───────────────────────────────────────────
  Widget _buildGlassAppBar(bool isDark, AuthState auth, List<String> tabNames) {
    final safeTop = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: safeTop),
          decoration: BoxDecoration(
            gradient: AppColors.gradientGlass(isDark: isDark, alpha: 0.88),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? AppColors.darkEnd : AppColors.lightEnd).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                const SizedBox(width: 16),
                // ── Title ──
                Expanded(
                  child: Text(
                    tabNames[_currentIndex],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      // Subtle premium glow instead of hard black shadow
                      shadows: [
                        Shadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                  ),
                ),

                // ── Add (Playlists tab only) ──
                if (_currentIndex == 2)
                  _AppBarIconButton(
                    icon: Icons.add,
                    isDark: isDark,
                    onPressed: () {
                      const PlaylistsScreen().showCreatePlaylistDialog(context, ref);
                    },
                    forceWhite: true,
                  ),

                // ── Account button ──
                Consumer(
                  builder: (ctx, ref, _) {
                    final a = ref.watch(authProvider);
                    return _AppBarIconButton(
                      isDark: isDark,
                      forceWhite: true,
                      onPressed: () async {
                        if (!a.isLoggedIn) {
                          await showAuthGate(ctx);
                        } else {
                          _showProfileSheet(ctx, a, isDark);
                        }
                      },
                      customChild: Icon(
                        a.isLoggedIn
                            ? Icons.account_circle_rounded
                            : Icons.account_circle_outlined,
                        size: 26,
                        color: Colors.white,
                      ),
                    );
                  },
                ),

                _AppBarIconButton(
                  icon: Icons.settings_outlined,
                  isDark: isDark,
                  forceWhite: true,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Glass Bottom NavBar ────────────────────────────────────────────────────
  Widget _buildGlassNavBar(bool isDark) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(bottom: safeBottom),
          decoration: BoxDecoration(
            color: AppColors.glassBackground(isDark: isDark),
            border: Border(
              top: BorderSide(
                color: AppColors.glassBorder(isDark: isDark),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? AppColors.darkStart : AppColors.lightStart)
                    .withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context: context, index: 0, icon: Icons.library_music_outlined,
                    activeIcon: Icons.library_music, label: 'Local', isDark: isDark),
                _buildNavItem(context: context, index: 1, icon: Icons.search_outlined,
                    activeIcon: Icons.search, label: 'Search', isDark: isDark),
                _buildNavItem(context: context, index: 2, icon: Icons.featured_play_list_outlined,
                    activeIcon: Icons.featured_play_list, label: 'Playlists', isDark: isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.darkStart.withValues(alpha: 0.18), AppColors.darkEnd.withValues(alpha: 0.12)]
                      : [AppColors.lightStart.withValues(alpha: 0.18), AppColors.lightEnd.withValues(alpha: 0.12)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            isSelected
                ? ShaderMask(
                    shaderCallback: (b) => AppColors.gradient(isDark: isDark)
                        .createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
                    child: Icon(activeIcon, color: Colors.white, size: 24),
                  )
                : Icon(
                    icon,
                    size: 24,
                    color: AppColors.textSecondary(isDark: isDark),
                  ),
            const SizedBox(height: 3),
            isSelected
                ? ShaderMask(
                    shaderCallback: (b) => AppColors.gradient(isDark: isDark)
                        .createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary(isDark: isDark),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // ── Profile Sheet ──────────────────────────────────────────────────────────
  void _showProfileSheet(BuildContext context, AuthState auth, bool isDark) {
    final cardColor = AppColors.cardColor(isDark: isDark);
    final textColor = AppColors.textPrimary(isDark: isDark);
    final subColor  = AppColors.textSecondary(isDark: isDark);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: AppColors.glassBorder(isDark: isDark), width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary(isDark: isDark).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Avatar with gradient
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.gradientDiagonal(isDark: isDark),
                    boxShadow: [AppColors.coloredShadow(isDark: isDark, opacity: 0.4)],
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  auth.userName ?? 'User',
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(auth.userEmail ?? '', style: TextStyle(color: subColor, fontSize: 13)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout_rounded, color: Color(0xFFFF5252)),
                    label: const Text('Keluar', style: TextStyle(color: Color(0xFFFF5252))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFF5252)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(authProvider.notifier).logout();
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────
class _AppBarIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? customChild;
  final bool isDark;
  final bool forceWhite;
  final VoidCallback onPressed;

  const _AppBarIconButton({
    this.icon,
    this.customChild,
    required this.isDark,
    required this.onPressed,
    this.forceWhite = false,
  }) : assert(icon != null || customChild != null);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: customChild ??
              Icon(
                icon,
                size: 24,
                color: forceWhite
                    ? Colors.white
                    : AppColors.textSecondary(isDark: isDark),
              ),
        ),
      ),
    );
  }
}

// Using Material Scaffold wrapper so Stack layout works cleanly
class MaterialScaffold extends StatelessWidget {
  final Widget body;
  final Color? backgroundColor;
  const MaterialScaffold({super.key, required this.body, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    // We use shadcn Scaffold which is aliased — use flutter's Scaffold directly via import alias
    return ColoredBox(
      color: backgroundColor ?? Colors.transparent,
      child: body,
    );
  }
}
