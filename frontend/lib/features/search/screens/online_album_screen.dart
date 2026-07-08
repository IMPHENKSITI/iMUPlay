import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Scaffold, AppBar, Positioned, Stack, Row, Column, Expanded, Theme, ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide showDialog, AlertDialog, CircularProgressIndicator, Slider, SliderTheme, Divider, Flexible, TextField, Colors, Icon, IconData, IconButton;

import '../models/online_song_model.dart';
import '../models/artist_profile_model.dart';
import '../repositories/album_repository.dart';
import '../../player/providers/audio_player_provider.dart';
import '../../playlists/widgets/add_to_playlist_modal.dart';
import '../../playlists/providers/database_provider.dart';
import '../../player/widgets/mini_player_bar.dart';

class OnlineAlbumScreen extends ConsumerStatefulWidget {
  final AlbumModel album;
  final String artistName;

  const OnlineAlbumScreen({
    super.key,
    required this.album,
    required this.artistName,
  });

  @override
  ConsumerState<OnlineAlbumScreen> createState() => _OnlineAlbumScreenState();
}

class _SearchScreenStateHelper {
  static Color getSourceColor(String source) {
    switch (source) {
      case 'youtube': return const Color(0xFFFF0000);
      case 'audius':  return const Color(0xFF7E1BCC);
      case 'jamendo': return const Color(0xFF009688);
      case 'itunes':  return const Color(0xFFEA4CC0);
      case 'soundcloud': return const Color(0xFFFF5500);
      default: return const Color(0xFF1DB954);
    }
  }

  static String getSourceLabel(String source) {
    switch (source) {
      case 'youtube': return 'YT';
      case 'audius': return 'AU';
      case 'jamendo': return 'JM';
      case 'itunes': return 'ITUN';
      case 'soundcloud': return 'SNDC';
      default: return source.toUpperCase();
    }
  }
}

class _OnlineAlbumScreenState extends ConsumerState<OnlineAlbumScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _playSongWithLoading(BuildContext context, OnlineSongModel song, List<OnlineSongModel> queue) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircularProgressIndicator(color: Color(0xFF1DB954)),
          ),
        ),
      ),
    );

    ref.read(audioHandlerProvider.notifier).playOnlineSong(
      song, 
      queue: queue,
    ).then((_) {
      if (context.mounted) Navigator.pop(context);
    }).catchError((_) {
      if (context.mounted) Navigator.pop(context);
    });
  }

  void _playAll(List<OnlineSongModel> queue) {
    if (queue.isEmpty) return;
    _playSongWithLoading(context, queue.first, queue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F8);

    final albumAsync = ref.watch(albumDetailsProvider(widget.album.id));
    final displaySongs = albumAsync.valueOrNull?.tracks ?? [];
    final displayArtwork = widget.album.thumbnail;

    double expandedHeight = 320;
    double offsetRatio = (_scrollOffset / (expandedHeight - kToolbarHeight)).clamp(0.0, 1.0);
    double imageScale = 1.0 - (offsetRatio * 0.3);
    double imageOpacity = 1.0 - (offsetRatio * 0.8);

    return Scaffold(
      backgroundColor: bgColor,
      child: Stack(
        children: [
          // Background Parallax Image
          if (displayArtwork != null)
            Positioned(
              top: 0 - (_scrollOffset * 0.5),
              left: 0,
              right: 0,
              height: expandedHeight,
              child: Opacity(
                opacity: imageOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: imageScale.clamp(0.5, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(displayArtwork),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Main Scrollable Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Transparent App Bar
              SliverAppBar(
                backgroundColor: bgColor.withValues(alpha: offsetRatio),
                elevation: 0,
                pinned: true,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                  ),
                ),
                title: AnimatedOpacity(
                  opacity: offsetRatio > 0.8 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    widget.album.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),

              // Header Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: expandedHeight - kToolbarHeight - 160,
                    bottom: 16,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bgColor.withValues(alpha: 0.0),
                          bgColor,
                        ],
                        stops: const [0.0, 0.4],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (displayArtwork != null)
                          Center(
                            child: Container(
                              width: 180,
                              height: 180,
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                                image: DecorationImage(
                                  image: NetworkImage(displayArtwork),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          widget.album.title,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: -1,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.artistName} • ${widget.album.year} • ${widget.album.trackCount} lagu',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: displaySongs.isEmpty ? null : () => _playAll(displaySongs),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: displaySongs.isEmpty ? textSecondary.withValues(alpha: 0.5) : const Color(0xFF1DB954),
                                  shape: BoxShape.circle,
                                  boxShadow: displaySongs.isEmpty ? [] : const [
                                    BoxShadow(
                                      color: Color(0x401DB954),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 36),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // Loading State
              if (albumAsync.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
                  ),
                ),

              // Songs List
              if (!albumAsync.isLoading && displaySongs.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = displaySongs[index];
                      return _buildSongTile(song, index, isDark, textPrimary, textSecondary, displaySongs);
                    },
                    childCount: displaySongs.length,
                  ),
                ),
                
              if (!albumAsync.isLoading && displaySongs.isEmpty && !albumAsync.hasError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'Tidak ada lagu di album ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ref.refresh(albumDetailsProvider(widget.album.id)),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF282828),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Error State
              if (albumAsync.hasError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'Gagal memuat lagu dari album.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ref.refresh(albumDetailsProvider(widget.album.id)),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF282828),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Bottom spacing for mini player
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
          
          // Mini Player
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayerPlaceholder(),
          ),
        ],
      ),
    );
  }

  Widget _buildSongTile(OnlineSongModel song, int index, bool isDark, Color textPrimary, Color textSecondary, List<OnlineSongModel> queue) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Play starting from this index
          final playQueue = queue.sublist(index) + queue.sublist(0, index);
          _playSongWithLoading(context, song, playQueue);
        },
        onLongPress: () => showAddToPlaylistModal(context, ref, onlineSong: song),
        highlightColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        splashColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              // Index
              SizedBox(
                width: 24,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 16),
              // Title & artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Source badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: _SearchScreenStateHelper.getSourceColor(song.source).withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _SearchScreenStateHelper.getSourceLabel(song.source),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _SearchScreenStateHelper.getSourceColor(song.source),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Favorite & Menu
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer(
                    builder: (context, ref, child) {
                      final favorites = ref.watch(onlineFavoritesProvider);
                      final isFavorite = favorites.any((f) => f.id == song.id && f.source == song.source);
                      
                      return GestureDetector(
                        onTap: () {
                          ref.read(onlineFavoritesProvider.notifier).toggleFavorite(song);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                            color: isFavorite ? const Color(0xFF1DB954) : textSecondary,
                            size: 20,
                          ),
                        ),
                      );
                    }
                  ),
                  GestureDetector(
                    onTap: () {
                      showAddToPlaylistModal(context, ref, onlineSong: song);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
