import 'package:flutter/material.dart' hide Scaffold, AppBar, IconButton, Positioned, Stack, Row, Column, Expanded, Theme, ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors, showDialog, AlertDialog, CircularProgressIndicator, Slider, SliderTheme, Divider, Flexible, TextField;

import '../../player/providers/audio_player_provider.dart';
import '../../player/widgets/mini_player_bar.dart';
import '../../search/models/online_song_model.dart';
import '../providers/database_provider.dart';

class OnlinePlaylistDetailScreen extends ConsumerWidget {
  final String playlistName;
  final bool isFavorites;

  const OnlinePlaylistDetailScreen({
    super.key,
    required this.playlistName,
    this.isFavorites = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    List<OnlineSongModel> playlistSongs = [];
    
    if (isFavorites) {
      playlistSongs = ref.watch(onlineFavoritesProvider);
    } else {
      final playlists = ref.watch(onlinePlaylistsProvider);
      final playlist = playlists.firstWhere(
        (p) => p.name == playlistName,
        orElse: () => OnlinePlaylistModel(name: playlistName, songs: []),
      );
      playlistSongs = playlist.songs;
    }

    return Scaffold(
      headers: [
        AppBar(
          leading: [
            IconButton.ghost(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          title: Text(playlistName),
          trailing: isFavorites 
            ? [] 
            : [
                 IconButton.ghost(
                   icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                   onPressed: () {
                     showDialog(
                       context: context,
                       builder: (context) => AlertDialog(
                         title: const Text('Hapus Playlist?'),
                         content: Text('Yakin ingin menghapus playlist "$playlistName"?'),
                         actions: [
                           OutlineButton(
                             onPressed: () => Navigator.pop(context),
                             child: const Text('Batal'),
                           ),
                           DestructiveButton(
                             onPressed: () {
                               ref.read(onlinePlaylistsProvider.notifier).deletePlaylist(playlistName);
                               Navigator.pop(context); // Close dialog
                               Navigator.pop(context); // Go back to playlists screen
                             },
                             child: const Text('Hapus'),
                           ),
                         ],
                       ),
                     );
                   }
                 )
              ]
        ),
      ],
      child: Stack(
        children: [
          playlistSongs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.foreground.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada lagu di playlist ini.',
                        style: TextStyle(color: theme.colorScheme.foreground.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120), // Padding for MiniPlayer
                  itemCount: playlistSongs.length,
                  itemBuilder: (context, index) {
                    final song = playlistSongs[index];
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282828) : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(8),
                          image: song.thumbnail != null
                              ? DecorationImage(
                                  image: NetworkImage(song.thumbnail!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: song.thumbnail == null
                            ? Icon(Icons.music_note, color: theme.colorScheme.foreground.withValues(alpha: 0.5))
                            : null,
                      ),
                      title: Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.colorScheme.foreground.withValues(alpha: 0.7),
                        ),
                      ),
                      trailing: IconButton.ghost(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: () {
                          if (isFavorites) {
                            ref.read(onlineFavoritesProvider.notifier).toggleFavorite(song);
                          } else {
                            ref.read(onlinePlaylistsProvider.notifier).removeSongFromPlaylist(playlistName, song.id);
                          }
                        },
                      ),
                      onTap: () {
                        _playSongWithLoading(context, ref, song, playlistSongs);
                      },
                    );
                  },
                ),
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

  Future<void> _playSongWithLoading(BuildContext context, WidgetRef ref, OnlineSongModel song, List<OnlineSongModel> queue) async {
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
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await ref.read(audioHandlerProvider.notifier).playOnlineSong(song, queue: queue);
    } finally {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
