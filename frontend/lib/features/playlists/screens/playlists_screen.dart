import 'package:flutter/material.dart' hide Scaffold, AppBar, IconButton, Positioned, Stack, Row, Column, Expanded, Theme, ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors, showDialog, AlertDialog, CircularProgressIndicator, Slider, SliderTheme, Divider, Flexible, TextField;

import '../providers/database_provider.dart';
import 'playlist_detail_screen.dart';
import 'online_playlist_detail_screen.dart';
import '../../../core/network/auth_provider.dart';

final playlistTabProvider = StateProvider<int>((ref) => 0);

class PlaylistsScreen extends ConsumerStatefulWidget {
  const PlaylistsScreen({super.key});

  void showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final isOnline = ref.read(playlistTabProvider) == 1;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final primary = isDark ? Colors.white : const Color(0xFF121212);
        final secondary = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);
        final inputBg = isDark ? const Color(0xFF282828) : const Color(0xFFF0F0F0);
        final typeText = isOnline ? 'Online' : 'Lokal';

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 8))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buat Playlist $typeText', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: primary, letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Text('Playlist akan disimpan di tab $typeText', style: TextStyle(fontSize: 13, color: secondary)),
                const SizedBox(height: 24),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    controller: controller,
                    style: TextStyle(color: primary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Nama Playlist',
                      hintStyle: TextStyle(color: secondary, fontSize: 15),
                      border: InputBorder.none,
                    ),
                    autofocus: true,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text('Batal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: secondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        final name = controller.text.trim();
                        if (name.isNotEmpty) {
                          if (isOnline) {
                            ref.read(onlinePlaylistsProvider.notifier).createPlaylist(name);
                          } else {
                            ref.read(playlistsProvider.notifier).createPlaylist(name);
                          }
                          Navigator.pop(context);
                          showToast(
                            context: context,
                            builder: (context, overlay) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
                              ),
                              child: Text('Playlist "$name" ($typeText) berhasil dibuat 🎵', style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Buat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends ConsumerState<PlaylistsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Inisialisasi tab controller dengan index dari provider agar tersinkronisasi
    _tabController = TabController(
      length: 2, 
      vsync: this, 
      initialIndex: ref.read(playlistTabProvider),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(playlistTabProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    
    // Jika tidak login, langsung tampilkan yang lokal saja tanpa TabBar
    if (!auth.isLoggedIn) {
      return const Scaffold(
        child: _LocalPlaylistsView(),
      );
    }
    
    // Dengarkan perubahan index dari luar (jika ada)
    ref.listen<int>(playlistTabProvider, (prev, next) {
      if (_tabController.index != next) {
        _tabController.animateTo(next);
      }
    });

    return Scaffold(
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.background,
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.foreground.withValues(alpha: 0.5),
              dividerColor: theme.colorScheme.border,
              tabs: const [
                Tab(text: 'Lokal'),
                Tab(text: 'Online'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _LocalPlaylistsView(),
                _OnlinePlaylistsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalPlaylistsView extends ConsumerWidget {
  const _LocalPlaylistsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final favorites = ref.watch(favoritesProvider);
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Favorites Card
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PlaylistDetailScreen(
                            playlistName: 'Lagu Favorit',
                            isFavorites: true,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.pinkAccent.withValues(alpha: 0.8),
                            Colors.deepPurpleAccent.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pinkAccent.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.white, size: 48),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lagu Favorit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${favorites.length} lagu',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Text('Koleksimu', style: theme.typography.h3),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          if (playlists.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.queue_music, size: 64, color: theme.colorScheme.foreground.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada playlist.',
                        style: TextStyle(color: theme.colorScheme.foreground.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final playlist = playlists[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlaylistDetailScreen(
                                playlistName: playlist.name,
                              ),
                            ),
                          );
                        },
                        onLongPress: () {
                          // Delete playlist confirmation
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Playlist?'),
                              content: Text('Yakin ingin menghapus playlist "${playlist.name}"?'),
                              actions: [
                                OutlineButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Batal'),
                                ),
                                DestructiveButton(
                                  onPressed: () {
                                    ref.read(playlistsProvider.notifier).deletePlaylist(playlist.name);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.library_music,
                              size: 48,
                              color: theme.colorScheme.primary.withValues(alpha: 0.8),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              playlist.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${playlist.songIds.length} lagu',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.foreground.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: playlists.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for mini player
        ],
    );
  }
}

class _OnlinePlaylistsView extends ConsumerWidget {
  const _OnlinePlaylistsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(onlinePlaylistsProvider);
    final onlineFavorites = ref.watch(onlineFavoritesProvider);
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Favorites Card
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OnlinePlaylistDetailScreen(
                          playlistName: 'Lagu Favorit',
                          isFavorites: true,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.pinkAccent.withValues(alpha: 0.8),
                          Colors.deepPurpleAccent.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.white, size: 48),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lagu Favorit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${onlineFavorites.length} lagu',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                Text('Koleksimu', style: theme.typography.h3),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        
        if (playlists.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.foreground.withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada playlist online.',
                      style: TextStyle(color: theme.colorScheme.foreground.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final playlist = playlists[index];
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OnlinePlaylistDetailScreen(
                            playlistName: playlist.name,
                          ),
                        ),
                      );
                    },
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Hapus Playlist?'),
                          content: Text('Yakin ingin menghapus playlist "${playlist.name}"?'),
                          actions: [
                            OutlineButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Batal'),
                            ),
                            DestructiveButton(
                              onPressed: () {
                                ref.read(onlinePlaylistsProvider.notifier).deletePlaylist(playlist.name);
                                Navigator.pop(context);
                              },
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (playlist.coverUrl != null)
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: Image.network(
                                  playlist.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Icon(Icons.cloud_queue, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Center(
                              child: Icon(
                                Icons.cloud_queue,
                                size: 48,
                                color: theme.colorScheme.primary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            playlist.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            '${playlist.songs.length} lagu',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.foreground.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: playlists.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)), // Space for mini player
      ],
    );
  }
}
