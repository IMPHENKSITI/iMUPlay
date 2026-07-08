import 'package:flutter/material.dart' hide Scaffold, AppBar, IconButton, Positioned, Stack, Row, Column, Expanded, Theme, ThemeData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart' hide PlaylistModel;
import 'package:shadcn_flutter/shadcn_flutter.dart' hide Colors, showDialog, AlertDialog, CircularProgressIndicator, Slider, SliderTheme, Divider, Flexible, TextField;

import '../../local_music/providers/audio_query_provider.dart';
import '../../player/providers/audio_player_provider.dart';
import '../../player/widgets/mini_player_bar.dart';
import '../providers/database_provider.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistName;
  final bool isFavorites;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistName,
    this.isFavorites = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final songsAsync = ref.watch(localSongsProvider);
    
    // Get the song IDs for this playlist
    List<int> songIds = [];
    if (isFavorites) {
      songIds = ref.watch(favoritesProvider);
    } else {
      final playlists = ref.watch(playlistsProvider);
      final playlist = playlists.firstWhere(
        (p) => p.name == playlistName,
        orElse: () => PlaylistModel(name: playlistName, songIds: []),
      );
      songIds = playlist.songIds;
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
        ),
      ],
      child: Stack(
        children: [
          songsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
            data: (allSongs) {
              // Filter all songs to only those in the playlist
              final playlistSongs = allSongs.where((song) => songIds.contains(song.id)).toList();

              if (playlistSongs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_off, size: 64, color: theme.colorScheme.foreground.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada lagu di sini.',
                        style: TextStyle(color: theme.colorScheme.foreground.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 120), // Padding for MiniPlayer
                itemCount: playlistSongs.length,
                itemBuilder: (context, index) {
                  final song = playlistSongs[index];
                  return ListTile(
                    leading: QueryArtworkWidget(
                      id: song.id,
                      type: ArtworkType.AUDIO,
                      nullArtworkWidget: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.music_note),
                      ),
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
                      song.artist ?? 'Unknown Artist',
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
                          ref.read(favoritesProvider.notifier).toggleFavorite(song.id);
                        } else {
                          ref.read(playlistsProvider.notifier).removeSongFromPlaylist(playlistName, song.id);
                        }
                      },
                    ),
                    onTap: () {
                      ref.read(audioHandlerProvider.notifier).playSong(song, queue: playlistSongs);
                    },
                  );
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
}
