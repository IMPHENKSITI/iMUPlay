import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Scaffold, AppBar, Positioned, Stack, Row, Column, Expanded, Theme, ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide showDialog, AlertDialog, CircularProgressIndicator, Slider, SliderTheme, Divider, Flexible, TextField, Colors, Icon, IconData, IconButton;

import '../models/online_song_model.dart';
import '../models/artist_profile_model.dart';
import '../repositories/artist_repository.dart';
import '../repositories/album_repository.dart';
import '../../player/providers/audio_player_provider.dart';
import '../../playlists/widgets/add_to_playlist_modal.dart';
import '../../playlists/providers/database_provider.dart';
import '../../player/widgets/mini_player_bar.dart';
import 'online_album_screen.dart';

class OnlineArtistScreen extends ConsumerStatefulWidget {
  final String artistName;
  final String? artworkUrl;
  final List<dynamic> songs; // List of OnlineSongModel

  const OnlineArtistScreen({
    super.key,
    required this.artistName,
    this.artworkUrl,
    required this.songs,
  });

  @override
  ConsumerState<OnlineArtistScreen> createState() => _OnlineArtistScreenState();
}

class _SearchScreenStateHelper {
  // Helper to reuse source colors
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
      case 'itunes': return 'ITUNES';
      case 'soundcloud': return 'SNDC';
      default: return source.toUpperCase();
    }
  }
}

class _OnlineArtistScreenState extends ConsumerState<OnlineArtistScreen> {
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

    // Play all songs starting from the selected one
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
    // Shuffle semua lagu (seperti Spotify "Putar Acak")
    final shuffled = List<OnlineSongModel>.from(queue)..shuffle();
    _playSongWithLoading(context, shuffled.first, shuffled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final textPrimary = isDark ? Colors.white : Colors.black;
    final textSecondary = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF8F8F8);

    final profileAsync = ref.watch(artistProfileProvider(widget.artistName));
    final profile = profileAsync.valueOrNull;

    final displayArtwork = profile?.artist.artwork ?? widget.artworkUrl;

    // Filter lagu: hanya tampilkan lagu yang benar-benar milik artis ini
    final artistNameLower = widget.artistName.toLowerCase();
    List<OnlineSongModel> filterByArtist(List<OnlineSongModel> songs) {
      return songs.where((s) {
        final a = s.artist.toLowerCase();
        return a.contains(artistNameLower) || artistNameLower.contains(a);
      }).toList();
    }

    final rawSongs = profile?.topTracks.isNotEmpty == true
        ? profile!.topTracks
        : widget.songs.cast<OnlineSongModel>();
    final displaySongs = filterByArtist(rawSongs);

    // Fade and size variables for the hero header
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
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              bgColor.withValues(alpha: 0.5),
                              bgColor,
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Main Content
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Transparent App Bar
              SliverAppBar(
                backgroundColor: bgColor.withValues(alpha: offsetRatio),
                elevation: 0,
                pinned: true,
                stretch: true,
                expandedHeight: expandedHeight,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: textPrimary, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  centerTitle: true,
                  title: Opacity(
                    opacity: offsetRatio,
                    child: Text(
                      widget.artistName,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Large Artwork in the center
                      Align(
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                              image: displayArtwork != null
                                  ? DecorationImage(
                                      image: NetworkImage(displayArtwork),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: isDark ? const Color(0xFF282828) : const Color(0xFFE0E0E0),
                            ),
                            child: displayArtwork == null
                                ? Icon(Icons.person, size: 80, color: textSecondary)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title and Play Button Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.artistName,
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
                        'Artis',
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
                            onTap: () => _playAll(displaySongs),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFF1DB954),
                                shape: BoxShape.circle,
                                boxShadow: [
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
                    ],
                  ),
                ),
              ),

              // Albums Carousel (Moved here)
              if (profile != null && profile.albums.isNotEmpty)
                _buildAlbumCarousel('Album', profile.albums, isDark, textPrimary, textSecondary),
              
              // Singles Carousel (Moved here)
              if (profile != null && profile.singles.isNotEmpty)
                _buildAlbumCarousel('Single & EP', profile.singles, isDark, textPrimary, textSecondary),

              // "Lagu Teratas" Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Text(
                    'Lagu Teratas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),

              // Songs List
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = displaySongs[index];
                    return _buildSongTile(song, index, isDark, textPrimary, textSecondary, displaySongs);
                  },
                  childCount: displaySongs.length,
                ),
              ),
              // Loading State
              if (profileAsync.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
                  ),
                ),

              // Error State
              if (profileAsync.hasError)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Text(
                            'Gagal memuat profil artis secara lengkap.\nMenampilkan data dasar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ref.refresh(artistProfileProvider(widget.artistName)),
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

              // Related Artists Carousel
              if (profile != null && profile.relatedArtists.isNotEmpty)
                _buildRelatedArtistsCarousel('Artis Terkait', profile.relatedArtists, isDark, textPrimary, textSecondary),
              
              // Bottom spacing for mini player
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
          
          // Mini Player
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MiniPlayerPlaceholder(),
          ),
        ],
      ),
    );
  }

  Widget _buildSongTile(OnlineSongModel song, int index, bool isDark, Color textPrimary, Color textSecondary, List<OnlineSongModel> queue) {
    final favorites = ref.watch(onlineFavoritesProvider);
    final isFavorite = favorites.any((s) => s.id == song.id && s.source == song.source);

    return InkWell(
      onTap: () => _playSongWithLoading(context, song, queue),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Number index
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
            // Artwork
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282828) : const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(6),
                image: song.thumbnail != null
                    ? DecorationImage(
                        image: NetworkImage(song.thumbnail!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: song.thumbnail == null
                  ? Icon(Icons.music_note_rounded, color: textSecondary)
                  : null,
            ),
            const SizedBox(width: 14),
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
                            color: textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    color: isFavorite ? const Color(0xFF1DB954) : textSecondary,
                    size: 22,
                  ),
                  onPressed: () {
                    ref.read(onlineFavoritesProvider.notifier).toggleFavorite(song);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.more_vert_rounded, color: textSecondary, size: 22),
                  onPressed: () => showAddToPlaylistModal(context, ref, onlineSong: song),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedArtistsCarousel(String title, List<ArtistInfoModel> relatedArtists, bool isDark, Color textPrimary, Color textSecondary) {
    if (relatedArtists.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: relatedArtists.length,
              itemBuilder: (context, index) {
                final artist = relatedArtists[index];
                return GestureDetector(
                  onTap: () {
                    // Navigate to a new OnlineArtistScreen for the related artist
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OnlineArtistScreen(
                          artistName: artist.name,
                          artworkUrl: artist.artwork,
                          songs: const [], // Empty songs initially, will fetch top tracks
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        // Circular Artwork Placeholder
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF282828) : const Color(0xFFE8E8E8),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            image: artist.artwork != null
                                ? DecorationImage(
                                    image: NetworkImage(artist.artwork!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: artist.artwork == null
                              ? Icon(Icons.person_rounded, size: 40, color: textSecondary)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        // Artist Name
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCarousel(String title, List<AlbumModel> items, bool isDark, Color textPrimary, Color textSecondary) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final album = items[index];
                return _buildAlbumCard(album, isDark, textPrimary, textSecondary);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(AlbumModel album, bool isDark, Color textPrimary, Color textSecondary) {
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover art dengan tombol ⋮ di pojok kanan atas
          Stack(
            children: [
              // Cover art (tappable → buka album)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OnlineAlbumScreen(
                      album: album,
                      artistName: widget.artistName,
                    ),
                  ),
                ),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282828) : const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: album.thumbnail != null
                        ? DecorationImage(
                            image: NetworkImage(album.thumbnail!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: album.thumbnail == null
                      ? Icon(Icons.album_rounded, color: textSecondary, size: 40)
                      : null,
                ),
              ),
              // Tombol ⋮ di pojok kanan atas
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTapDown: (details) => _showAlbumMenu(details.globalPosition, album, isDark, textPrimary, textSecondary),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Judul album
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OnlineAlbumScreen(
                  album: album,
                  artistName: widget.artistName,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${album.year} • ${album.trackCount} lagu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAlbumMenu(Offset position, AlbumModel album, bool isDark, Color textPrimary, Color textSecondary) async {
    final screenSize = MediaQuery.of(context).size;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        screenSize.width - position.dx,
        screenSize.height - position.dy,
      ),
      color: isDark ? const Color(0xFF282828) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          value: 'queue',
          child: Row(
            children: [
              Icon(Icons.queue_music_rounded, color: textSecondary, size: 20),
              const SizedBox(width: 12),
              Text('Tambah ke Antrian', style: TextStyle(color: textPrimary, fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'playlist',
          child: Row(
            children: [
              Icon(Icons.playlist_add_rounded, color: textSecondary, size: 20),
              const SizedBox(width: 12),
              Text('Tambah ke Playlist', style: TextStyle(color: textPrimary, fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'like',
          child: Row(
            children: [
              const Icon(Icons.favorite_outline_rounded, color: Color(0xFF1DB954), size: 20),
              const SizedBox(width: 12),
              Text('Suka Album Ini', style: TextStyle(color: textPrimary, fontSize: 14)),
            ],
          ),
        ),
      ],
    );

    if (value == null || !mounted) return;

    // Fetch lagu album terlebih dahulu (untuk like-all dan add-to-playlist)
    Future<List<OnlineSongModel>> fetchTracks() async {
      final repo = ref.read(albumRepositoryProvider);
      try {
        final details = await repo.getAlbumDetails(album.id);
        return details.tracks;
      } catch (_) {
        return [];
      }
    }

    switch (value) {
      case 'queue':
        final queueSnack = showToast(
          context: context,
          showDuration: const Duration(seconds: 10),
          builder: (context, overlay) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Memuat lagu album...', style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        );
        
        final tracks = await fetchTracks();
        
        queueSnack.close();
        
        if (tracks.isNotEmpty && mounted) {
          ref.read(audioHandlerProvider.notifier).addMultipleOnlineToQueue(tracks);
          showToast(
            context: context,
            showDuration: const Duration(seconds: 3),
            builder: (context, overlay) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Text('Menambahkan ${tracks.length} lagu dari "${album.title}" ke antrean 🎶', style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          );
        }
        break;

      case 'playlist':
        // Fetch semua lagu album, lalu buka modal add-to-playlist dengan bulk songs
        final tracks = await fetchTracks();
        if (!mounted) return;
        showAlbumAddToPlaylistModal(
          context,
          ref,
          albumName: album.title,
          coverUrl: album.thumbnail,
          songs: tracks,
        );
        break;

      case 'like':
        // Fetch semua lagu, lalu like satu per satu
        final likeSnack = showToast(
          context: context,
          showDuration: const Duration(seconds: 10),
          builder: (context, overlay) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF282828),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Mengambil lagu album…', style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        );
        final likeTracks = await fetchTracks();
        likeSnack.close();
        if (!mounted) return;
        for (final track in likeTracks) {
          ref.read(onlineFavoritesProvider.notifier).toggleFavorite(track);
          // Hanya tambahkan, jangan toggle off kalau sudah ada
          if (!ref.read(onlineFavoritesProvider.notifier).isFavorite(track.id)) {
            ref.read(onlineFavoritesProvider.notifier).toggleFavorite(track);
          }
        }
        if (!mounted) return;
        showToast(
          context: context,
          showDuration: const Duration(seconds: 3),
          builder: (context, overlay) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Text('${likeTracks.length} lagu dari "${album.title}" disukai ❤️', style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        );
        break;
    }
  }
}
