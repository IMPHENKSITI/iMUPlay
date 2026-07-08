import 'dart:async';
import 'package:flutter/material.dart' hide Scaffold, AppBar, IconButton, Positioned, Stack, Row, Column, Expanded, Theme, ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide showDialog, AlertDialog, CircularProgressIndicator, Slider, SliderTheme, Divider, Flexible, TextField, Colors, Icon, IconData;

import '../providers/online_search_provider.dart';
import '../providers/browse_provider.dart';
import '../../player/providers/audio_player_provider.dart';
import '../../playlists/widgets/add_to_playlist_modal.dart';
import '../../playlists/providers/database_provider.dart';

import 'online_artist_screen.dart';
import '../providers/search_history_provider.dart';
import '../../../core/network/auth_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _isSearchMode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    // Initialize browse sections on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(browseProvider.notifier).initialize();
    });

    _searchController.addListener(() {
      final query = _searchController.text.trim();
      setState(() {
        _isSearchMode = query.isNotEmpty;
      });
    });

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).addSearch(query);
      ref.read(onlineSearchProvider.notifier).search(query);
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchState = ref.watch(onlineSearchProvider);
    final browseState = ref.watch(browseProvider);
    final searchHistory = ref.watch(searchHistoryProvider);

    final textPrimary = isDark ? Colors.white : const Color(0xFF191414);
    final textSecondary = isDark ? const Color(0xFFB3B3B3) : const Color(0xFF6B6B6B);
    final searchBg = isDark ? const Color(0xFF282828) : Colors.white;

    final auth = ref.watch(authProvider);

    if (!auth.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Fitur Pencarian Online',
              style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Anda harus masuk (login) terlebih dahulu untuk mencari dan memutar lagu secara online.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ─── SEARCH BAR (Spotify style) ───
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(Icons.search_rounded, size: 22, color: textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: TextStyle(color: textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Mau dengar apa?',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 15),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                if (_isSearchMode)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      ref.read(onlineSearchProvider.notifier).clear();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.close_rounded, size: 20, color: textSecondary),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ─── CONTENT ───
        Expanded(
          child: _isSearchMode
              ? _buildSearchResults(searchState, theme, isDark, textPrimary, textSecondary)
              : _isFocused
                  ? _buildSearchHistory(searchHistory, isDark, textPrimary, textSecondary)
                  : _buildBrowseView(browseState, theme, isDark, textPrimary, textSecondary),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  SEARCH HISTORY VIEW
  // ═══════════════════════════════════════════
  Widget _buildSearchHistory(List<String> history, bool isDark, Color textPrimary, Color textSecondary) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada riwayat pencarian.',
          style: TextStyle(color: textSecondary, fontSize: 14),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Baru-baru ini',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  ref.read(searchHistoryProvider.notifier).clearHistory();
                },
                child: Text(
                  'Hapus Semua',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final item = history[index];
              return ListTile(
                leading: Icon(Icons.history_rounded, color: textSecondary, size: 24),
                title: Text(
                  item,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                trailing: GestureDetector(
                  onTap: () {
                    ref.read(searchHistoryProvider.notifier).removeSearch(item);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                  ),
                ),
                onTap: () {
                  _searchController.text = item;
                  _performSearch();
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  BROWSE VIEW (Spotify-style horizontal carousels per genre)
  // ═══════════════════════════════════════════
  Widget _buildBrowseView(
    BrowseState browseState,
    ThemeData theme,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (browseState.sections.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      color: const Color(0xFF1DB954),
      backgroundColor: isDark ? const Color(0xFF282828) : Colors.white,
      onRefresh: () async {
        await ref.read(browseProvider.notifier).initialize(forceRefresh: true);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: browseState.sections.length + 1, // +1 for genre chips at top
        itemBuilder: (context, index) {
          // First item: Quick genre chip row
          if (index == 0) {
            return _buildQuickGenreChips(theme, isDark, textPrimary, textSecondary);
          }

          final section = browseState.sections[index - 1];
          return _buildSectionCarousel(section, index - 1, theme, isDark, textPrimary, textSecondary);
        },
      ),
    );
  }

  /// Quick genre chips at the top (tappable shortcuts)
  Widget _buildQuickGenreChips(ThemeData theme, bool isDark, Color textPrimary, Color textSecondary) {
    final quickGenres = ['Pop', 'Rock', 'Jazz', 'EDM', 'R&B', 'Hip-Hop', 'Akustik', 'Indonesia'];
    final chipColors = [
      const Color(0xFF1DB954),
      const Color(0xFFE91E63),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFF2196F3),
      const Color(0xFFFF5722),
      const Color(0xFF00BCD4),
      const Color(0xFFFF4081),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: quickGenres.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                _searchController.text = quickGenres[index];
                _performSearch();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: chipColors[index % chipColors.length].withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: chipColors[index % chipColors.length].withValues(alpha: isDark ? 0.4 : 0.3),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  quickGenres[index],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? chipColors[index % chipColors.length].withValues(alpha: 0.9) : chipColors[index % chipColors.length],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// A single horizontal carousel section
  Widget _buildSectionCarousel(
    GenreSection section,
    int sectionIndex,
    ThemeData theme,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
                if (section.error != null)
                  GestureDetector(
                    onTap: () => ref.read(browseProvider.notifier).retrySection(sectionIndex),
                    child: Text(
                      'Coba lagi',
                      style: TextStyle(fontSize: 13, color: const Color(0xFF1DB954), fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          if (section.isLoading)
            _buildShimmerRow(isDark)
          else if (section.error != null && section.songs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, color: textSecondary, size: 28),
                    const SizedBox(height: 8),
                    Text('Gagal memuat', style: TextStyle(color: textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (section.songs.isEmpty)
            const SizedBox(height: 20)
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: section.songs.length,
                itemBuilder: (context, index) {
                  final song = section.songs[index];
                  return _buildSongCard(song, isDark, textPrimary, textSecondary);
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Spotify-style song card (vertical: cover + title + artist)
  Widget _buildSongCard(dynamic song, bool isDark, Color textPrimary, Color textSecondary) {
    return GestureDetector(
      onTap: () => _playSongWithLoading(context, song),
      onLongPress: () => showAddToPlaylistModal(context, ref, onlineSong: song),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover art
            Stack(
              children: [
                Container(
                  height: 140,
                  width: 140,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282828) : const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    image: song.thumbnail != null
                        ? DecorationImage(
                            image: NetworkImage(song.thumbnail!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: song.thumbnail == null
                      ? Center(
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 40,
                            color: isDark ? const Color(0xFF535353) : const Color(0xFFBBBBBB),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTapDown: (details) {
                      _showSongMenu(details.globalPosition, song, isDark, textPrimary, textSecondary);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Title
            Text(
              song.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            // Artist
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSongMenu(Offset position, dynamic song, bool isDark, Color textPrimary, Color textSecondary) async {
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
      ],
    );

    if (value == null || !mounted) return;

    if (value == 'queue') {
      ref.read(audioHandlerProvider.notifier).addOnlineSongToQueue(song);
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
          child: const Text('Ditambahkan ke antrean 🎶', style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
      );
    } else if (value == 'playlist') {
      showAddToPlaylistModal(context, ref, onlineSong: song);
    }
  }

  /// Shimmer/placeholder row for loading state
  Widget _buildShimmerRow(bool isDark) {
    final shimmerColor = isDark ? const Color(0xFF282828) : const Color(0xFFE8E8E8);
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            width: 140,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 140,
                  width: 140,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(height: 12, width: 100, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 6),
                Container(height: 10, width: 70, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(
    AsyncValue<List<dynamic>> searchState,
    ThemeData theme,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    return RefreshIndicator(
      color: const Color(0xFF1DB954),
      backgroundColor: isDark ? const Color(0xFF282828) : Colors.white,
      onRefresh: () async {
        final query = _searchController.text.trim();
        if (query.isNotEmpty) {
          await ref.read(onlineSearchProvider.notifier).search(query);
        }
      },
      child: searchState.when(
      loading: () => _buildSearchLoadingShimmer(isDark),
      error: (error, stack) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF282828) : const Color(0xFFF0F0F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.wifi_off_rounded, size: 36, color: textSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gagal mencari',
                  style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tarik ke bawah untuk mengulang',
                  style: TextStyle(color: textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (allSongs) {
        final songs = allSongs.where((s) => s.isStreamable == true && s.duration > 0).toList();
        
        if (songs.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF282828) : const Color(0xFFF0F0F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.search_off_rounded, size: 36, color: textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ditemukan lagu yang bisa diputar',
                    style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Coba kata kunci lain atau tarik ke bawah untuk menyegarkan',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // --- Ekstrak Top Artists ---
        final artistCount = <String, int>{};
        for (final song in songs) {
          final artist = song.artist as String;
          artistCount[artist] = (artistCount[artist] ?? 0) + 1;
        }

        // Urutkan berdasarkan frekuensi (terbanyak)
        final sortedArtists = artistCount.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        List<String> topArtists = sortedArtists.map((e) => e.key).toList();

        // Prioritaskan artis yang namanya cocok persis
        final queryLower = _searchController.text.trim().toLowerCase();
        final queryWords = queryLower.split(RegExp(r'\s+'));
        
        String? exactMatchArtist;
        for (final artist in topArtists) {
          final artistLower = artist.toLowerCase();
          bool isMatch = true;
          for (final word in queryWords) {
            if (!artistLower.contains(word)) {
              isMatch = false;
              break;
            }
          }
          if (isMatch) {
            exactMatchArtist = artist;
            break;
          }
        }

        if (exactMatchArtist != null) {
          topArtists.remove(exactMatchArtist);
          topArtists.insert(0, exactMatchArtist);
        }

        // Batasi maksimal 10 artis
        if (topArtists.length > 10) {
          topArtists = topArtists.sublist(0, 10);
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // ── ARTIS TERKAIT CARD ──
            if (topArtists.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 0, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Artis Terkait',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: topArtists.length,
                        itemBuilder: (context, index) {
                          final artistName = topArtists[index];
                          final artistFirstSong = songs.firstWhere((s) => s.artist == artistName);
                          
                          return GestureDetector(
                            onTap: () {
                              final artistSongs = songs.where((s) => s.artist == artistName).toList();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OnlineArtistScreen(
                                    artistName: artistName,
                                    artworkUrl: artistFirstSong.thumbnail,
                                    songs: artistSongs,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 104,
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Container(
                                    width: 92,
                                    height: 92,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF282828) : const Color(0xFFE0E0E0),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: (artistFirstSong.thumbnail != null && artistFirstSong.thumbnail!.toString().isNotEmpty)
                                          ? Image.network(
                                              artistFirstSong.thumbnail!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Icon(
                                                Icons.person_rounded,
                                                size: 40,
                                                color: isDark ? const Color(0xFF535353) : const Color(0xFFBBBBBB),
                                              ),
                                            )
                                          : Icon(
                                              Icons.person_rounded,
                                              size: 40,
                                              color: isDark ? const Color(0xFF535353) : const Color(0xFFBBBBBB),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    artistName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      height: 1.2,
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
              ),

            // ── SECTION HEADER: Lagu ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Lagu',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),

            // ── DAFTAR LAGU ──
            ...songs.asMap().entries.map((entry) {
              final index = entry.key;
              final song = entry.value;
              return _buildSongListTile(song, index, isDark, textPrimary, textSecondary);
            }),
          ],
        );
      },
    ));
  }

  /// Spotify-style song list tile (horizontal row)
  Widget _buildSongListTile(dynamic song, int index, bool isDark, Color textPrimary, Color textSecondary) {
    return InkWell(
      onTap: () => _playSongWithLoading(context, song),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // Artwork
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282828) : const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: (song.thumbnail != null && song.thumbnail!.toString().isNotEmpty)
                    ? Image.network(
                        song.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.music_note_rounded,
                          color: textSecondary,
                        ),
                      )
                    : Icon(
                        Icons.music_note_rounded,
                        color: textSecondary,
                      ),
              ),
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
                      fontSize: 15,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Source badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: _getSourceColor(song.source).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getSourceLabel(song.source),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _getSourceColor(song.source),
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
                            color: textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Favorite Button
            Consumer(
              builder: (context, ref, child) {
                final isFav = ref.watch(onlineFavoritesProvider.notifier).isFavorite(song.id);
                ref.watch(onlineFavoritesProvider);

                return GestureDetector(
                  onTap: () {
                    ref.read(onlineFavoritesProvider.notifier).toggleFavorite(song);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 20,
                      color: isFav ? const Color(0xFF1DB954) : textSecondary,
                    ),
                  ),
                );
              },
            ),
            // More options
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showAddToPlaylistModal(context, ref, onlineSong: song),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Icon(Icons.more_vert_rounded, size: 20, color: textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'youtube': return const Color(0xFFFF0000);
      case 'audius': return const Color(0xFF7E1BCC);
      case 'jamendo': return const Color(0xFF009688);
      case 'itunes': return const Color(0xFFEA4CC0);
      case 'soundcloud': return const Color(0xFFFF5500);
      default: return const Color(0xFF1DB954);
    }
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'youtube': return 'YT';
      case 'audius': return 'AU';
      case 'jamendo': return 'JM';
      case 'itunes': return 'ITUN';
      case 'soundcloud': return 'SNDC';
      default: return source.toUpperCase();
    }
  }

  /// Shimmer loading for search results
  Widget _buildSearchLoadingShimmer(bool isDark) {
    final shimmerBase = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0);
    final shimmerHighlight = isDark ? const Color(0xFF282828) : const Color(0xFFE0E0E0);

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        // Top Result shimmer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 20, width: 120, decoration: BoxDecoration(color: shimmerBase, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Container(
                height: 132,
                decoration: BoxDecoration(color: shimmerBase, borderRadius: BorderRadius.circular(12)),
              ),
            ],
          ),
        ),
        // Song list shimmer
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(height: 20, width: 50, decoration: BoxDecoration(color: shimmerBase, borderRadius: BorderRadius.circular(4))),
        ),
        ...List.generate(6, (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: shimmerHighlight, borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 180, decoration: BoxDecoration(color: shimmerHighlight, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 120, decoration: BoxDecoration(color: shimmerHighlight, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Future<void> _playSongWithLoading(BuildContext context, dynamic song) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF1DB954)),
              const SizedBox(height: 16),
              Text(
                'Memuat lagu...',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await ref.read(audioHandlerProvider.notifier).playOnlineSong(song);
    } finally {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
