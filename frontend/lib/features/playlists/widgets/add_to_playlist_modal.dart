import 'dart:ui';
import 'package:flutter/material.dart' hide Scaffold, AppBar, IconButton, Positioned, Stack, Row, Column, Expanded, Theme, ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors, showDialog, AlertDialog, CircularProgressIndicator, Slider, SliderTheme, Divider, Flexible, TextField;
import 'package:on_audio_query/on_audio_query.dart' hide PlaylistModel;

import '../providers/database_provider.dart';
import '../../player/providers/audio_player_provider.dart';
import '../../search/models/online_song_model.dart';
import '../../../shared/theme/app_colors.dart';

// ─── Single song modal ─────────────────────────────────────────────────────────
void showAddToPlaylistModal(BuildContext context, WidgetRef ref,
    {SongModel? localSong, OnlineSongModel? onlineSong}) {
  assert(localSong != null || onlineSong != null,
      'Harus mengirimkan localSong atau onlineSong');
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) =>
        _AddToPlaylistModal(localSong: localSong, onlineSong: onlineSong),
  );
}

// ─── Album bulk modal ──────────────────────────────────────────────────────────
void showAlbumAddToPlaylistModal(
  BuildContext context,
  WidgetRef ref, {
  required String albumName,
  String? coverUrl,
  required List<OnlineSongModel> songs,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _AlbumAddToPlaylistModal(
      albumName: albumName,
      coverUrl: coverUrl,
      songs: songs,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SINGLE SONG MODAL
// ═══════════════════════════════════════════════════════════════════════════════
class _AddToPlaylistModal extends ConsumerStatefulWidget {
  final SongModel? localSong;
  final OnlineSongModel? onlineSong;
  const _AddToPlaylistModal({this.localSong, this.onlineSong});

  @override
  ConsumerState<_AddToPlaylistModal> createState() => _AddToPlaylistModalState();
}

class _AddToPlaylistModalState extends ConsumerState<_AddToPlaylistModal> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _isOnline => widget.onlineSong != null;

  void _createNewPlaylist() {
    final name = _ctrl.text.trim();
    if (name.isNotEmpty) {
      if (_isOnline) {
        ref.read(onlinePlaylistsProvider.notifier).createPlaylist(name);
        ref.read(onlinePlaylistsProvider.notifier).addSongToPlaylist(name, widget.onlineSong!);
      } else {
        ref.read(playlistsProvider.notifier).createPlaylist(name);
        ref.read(playlistsProvider.notifier).addSongToPlaylist(name, widget.localSong!.id);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final onlinePlaylists = ref.watch(onlinePlaylistsProvider);
    final localPlaylists  = ref.watch(playlistsProvider);
    final count           = _isOnline ? onlinePlaylists.length : localPlaylists.length;

    return _GlassModalSheet(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Song info header ──
          _SongHeader(
            title: _isOnline ? (widget.onlineSong?.title ?? '') : (widget.localSong?.title ?? ''),
            artist: _isOnline ? (widget.onlineSong?.artist ?? '') : (widget.localSong?.artist ?? ''),
            thumbnail: _isOnline ? widget.onlineSong?.thumbnail : null,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // ── Add to queue action ──
          _ActionChip(
            icon: Icons.queue_music_rounded,
            label: 'Tambahkan ke Antrian',
            isDark: isDark,
            onTap: () {
              if (_isOnline) {
                ref.read(audioHandlerProvider.notifier).addOnlineSongToQueue(widget.onlineSong!);
              } else {
                ref.read(audioHandlerProvider.notifier).addToQueue(widget.localSong!);
              }
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),

          // ── New playlist input ──
          _NewPlaylistInput(
            ctrl: _ctrl,
            isDark: isDark,
            onCreated: _createNewPlaylist,
          ),

          // ── Playlist list label ──
          if (count > 0) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                'Playlist Saya',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(isDark: isDark),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final String name; final int songs; final bool isAdded; final String? cover;
                  if (_isOnline) {
                    final p = onlinePlaylists[i];
                    name = p.name; songs = p.songs.length; cover = p.coverUrl;
                    isAdded = ref.read(onlinePlaylistsProvider.notifier).isSongInPlaylist(name, widget.onlineSong!.id);
                  } else {
                    final p = localPlaylists[i];
                    name = p.name; songs = p.songIds.length; cover = null;
                    isAdded = ref.read(playlistsProvider.notifier).isSongInPlaylist(name, widget.localSong!.id);
                  }
                  return _ModernPlaylistTile(
                    name: name, songCount: songs, coverUrl: cover,
                    isDark: isDark, isAdded: isAdded,
                    onTap: () {
                      if (_isOnline) {
                        isAdded
                            ? ref.read(onlinePlaylistsProvider.notifier).removeSongFromPlaylist(name, widget.onlineSong!.id)
                            : ref.read(onlinePlaylistsProvider.notifier).addSongToPlaylist(name, widget.onlineSong!);
                      } else {
                        isAdded
                            ? ref.read(playlistsProvider.notifier).removeSongFromPlaylist(name, widget.localSong!.id)
                            : ref.read(playlistsProvider.notifier).addSongToPlaylist(name, widget.localSong!.id);
                      }
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(Icons.playlist_add_rounded, size: 36,
                      color: AppColors.textSecondary(isDark: isDark).withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada playlist',
                    style: TextStyle(color: AppColors.textSecondary(isDark: isDark), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Buat playlist baru di atas!',
                    style: TextStyle(
                      color: AppColors.primary(isDark: isDark),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ALBUM BULK MODAL
// ═══════════════════════════════════════════════════════════════════════════════
class _AlbumAddToPlaylistModal extends ConsumerStatefulWidget {
  final String albumName;
  final String? coverUrl;
  final List<OnlineSongModel> songs;
  const _AlbumAddToPlaylistModal({required this.albumName, this.coverUrl, required this.songs});

  @override
  ConsumerState<_AlbumAddToPlaylistModal> createState() => _AlbumAddToPlaylistModalState();
}

class _AlbumAddToPlaylistModalState extends ConsumerState<_AlbumAddToPlaylistModal> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.albumName);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _createAndAdd() {
    final name = _ctrl.text.trim();
    if (name.isNotEmpty) {
      ref.read(onlinePlaylistsProvider.notifier)
          .createPlaylistWithSongs(name, widget.songs, coverUrl: widget.coverUrl);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final playlists = ref.watch(onlinePlaylistsProvider);

    return _GlassModalSheet(
      isDark: isDark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album header
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: AppColors.gradientDiagonal(isDark: isDark),
                image: widget.coverUrl != null
                    ? DecorationImage(image: NetworkImage(widget.coverUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: widget.coverUrl == null
                  ? const Icon(Icons.album_rounded, color: Colors.white, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Tambah Album',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.primary(isDark: isDark), letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.albumName,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(isDark: isDark),
                ),
              ),
              Text(
                '${widget.songs.length} lagu',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(isDark: isDark)),
              ),
            ])),
          ]),
          const SizedBox(height: 16),

          _NewPlaylistInput(ctrl: _ctrl, isDark: isDark, onCreated: _createAndAdd),

          if (playlists.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text(
                'Tambah ke Playlist Ada',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(isDark: isDark), letterSpacing: 0.8,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: playlists.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (ctx, i) {
                  final p = playlists[i];
                  return _ModernPlaylistTile(
                    name: p.name, songCount: p.songs.length, coverUrl: p.coverUrl,
                    isDark: isDark, isAdded: false,
                    onTap: () {
                      ref.read(onlinePlaylistsProvider.notifier).addSongsToPlaylist(p.name, widget.songs);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Glass bottom sheet wrapper
class _GlassModalSheet extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _GlassModalSheet({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: 0,
            left: 20, right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardColor(isDark: isDark).withValues(alpha: 0.93),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AppColors.glassBorder(isDark: isDark), width: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? AppColors.darkStart : AppColors.lightStart).withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle with gradient tint
              const SizedBox(height: 10),
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.darkStart.withValues(alpha: 0.5), AppColors.darkEnd.withValues(alpha: 0.5)]
                        : [AppColors.lightStart.withValues(alpha: 0.5), AppColors.lightEnd.withValues(alpha: 0.5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Song info row at top of single-song modal
class _SongHeader extends StatelessWidget {
  final String title;
  final String artist;
  final String? thumbnail;
  final bool isDark;
  const _SongHeader({required this.title, required this.artist, this.thumbnail, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: AppColors.gradientDiagonal(isDark: isDark),
            image: thumbnail != null
                ? DecorationImage(image: NetworkImage(thumbnail!), fit: BoxFit.cover)
                : null,
          ),
          child: thumbnail == null
              ? const Icon(Icons.music_note_rounded, color: Colors.white, size: 26)
              : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tambah ke Playlist',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.primary(isDark: isDark), letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(isDark: isDark),
                ),
              ),
              Text(
                artist,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary(isDark: isDark)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Tambahkan ke Antrian" chip style
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary(isDark: isDark).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary(isDark: isDark).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (b) => AppColors.gradient(isDark: isDark)
                  .createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary(isDark: isDark),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// New playlist input + gradient create button
class _NewPlaylistInput extends StatelessWidget {
  final TextEditingController ctrl;
  final bool isDark;
  final VoidCallback onCreated;
  const _NewPlaylistInput({required this.ctrl, required this.isDark, required this.onCreated});

  @override
  Widget build(BuildContext context) {
    final inputBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F7);

    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary(isDark: isDark).withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: ctrl,
            style: TextStyle(
              color: AppColors.textPrimary(isDark: isDark),
              fontSize: 15, fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Nama playlist baru...',
              hintStyle: TextStyle(
                color: AppColors.textSecondary(isDark: isDark),
                fontSize: 15, fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (_) => onCreated(),
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: onCreated,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: AppColors.gradient(isDark: isDark),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [AppColors.coloredShadow(isDark: isDark, opacity: 0.35)],
          ),
          child: const Center(
            child: Text(
              'Buat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Modern playlist tile (card style, not bare ListTile)
class _ModernPlaylistTile extends StatelessWidget {
  final String name;
  final int songCount;
  final String? coverUrl;
  final bool isDark;
  final bool isAdded;
  final VoidCallback onTap;
  const _ModernPlaylistTile({
    required this.name, required this.songCount, this.coverUrl,
    required this.isDark, required this.isAdded, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isAdded
              ? AppColors.primary(isDark: isDark).withValues(alpha: 0.1)
              : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8)),
          borderRadius: BorderRadius.circular(14),
          border: isAdded
              ? Border.all(color: AppColors.primary(isDark: isDark).withValues(alpha: 0.3))
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            // Cover art
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: isDark
                      ? [AppColors.darkStart.withValues(alpha: 0.7), AppColors.darkEnd.withValues(alpha: 0.7)]
                      : [AppColors.lightStart.withValues(alpha: 0.7), AppColors.lightEnd.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: coverUrl != null
                    ? DecorationImage(image: NetworkImage(coverUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: coverUrl == null
                  ? Icon(Icons.queue_music_rounded, color: Colors.white.withValues(alpha: 0.9), size: 22)
                  : null,
            ),
            const SizedBox(width: 12),
            // Name + count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: AppColors.textPrimary(isDark: isDark),
                      fontWeight: FontWeight.w700, fontSize: 15,
                    ),
                  ),
                  Text(
                    '$songCount lagu',
                    style: TextStyle(
                      color: AppColors.textSecondary(isDark: isDark), fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Check / Add icon with gradient
            ShaderMask(
              shaderCallback: (b) => AppColors.gradient(isDark: isDark)
                  .createShader(Rect.fromLTWH(0, 0, b.width, b.height)),
              child: Icon(
                isAdded ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
