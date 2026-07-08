import 'package:flutter/material.dart' hide Scaffold, AppBar, Divider, Row, Column, Expanded, Colors, Theme, ThemeData, ListTile;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide IconButton;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../providers/audio_player_provider.dart';
import '../../history/providers/history_provider.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(audioHandlerProvider);
    final history = ref.watch(historyProvider);
    
    final audioNotifier = ref.read(audioHandlerProvider.notifier);
    final queue = audioNotifier.currentQueue;
    final currentIndex = audioNotifier.currentIndex;

    final nextSongs = queue.skip(currentIndex + 1).toList();

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Antrean Pemutaran'),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton('Berikutnya', 0),
                const SizedBox(width: 8),
                _buildTabButton('Riwayat', 1),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _selectedTab == 0
                ? _buildNextUpList(nextSongs, queue.length > currentIndex && currentIndex >= 0 ? queue[currentIndex] : null, currentIndex)
                : _buildHistoryList(history),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.border,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.primaryForeground : Theme.of(context).colorScheme.foreground,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildNextUpList(List<SongModel> nextSongs, SongModel? currentSong, int currentIndex) {
    if (currentSong == null && nextSongs.isEmpty) {
      return const Center(child: Text('Tidak ada antrean'));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (currentSong != null) ...[
          const Text('Sedang Diputar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 300)),
          const SizedBox(height: 8),
          _buildSongTile(currentSong, isPlaying: true, showDragHandle: false),
          const SizedBox(height: 24),
        ],
        if (nextSongs.isNotEmpty) ...[
          const Text('Berikutnya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 300)),
          const SizedBox(height: 8),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            proxyDecorator: (Widget child, int index, Animation<double> animation) {
              final theme = Theme.of(context);
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? child) {
                  final double animValue = Curves.easeInOut.transform(animation.value);
                  final double scale = 1.0 + (0.02 * animValue);
                  return Transform.scale(
                    scale: scale,
                    child: Material(
                      color: theme.colorScheme.background,
                      elevation: 0,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withValues(alpha: 0.2 * animValue),
                              blurRadius: 10 * animValue,
                              spreadRadius: 1 * animValue,
                              offset: Offset(0, 4 * animValue),
                            )
                          ],
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
                child: child,
              );
            },
            onReorderItem: (int oldIndex, int newIndex) {
              // Map from list index to queue index
              final queueOldIndex = currentIndex + 1 + oldIndex;
              final queueNewIndex = currentIndex + 1 + (newIndex > oldIndex ? newIndex - 1 : newIndex);
              ref.read(audioHandlerProvider.notifier).reorderQueue(queueOldIndex, queueNewIndex);
            },
            children: nextSongs.asMap().entries.map((entry) => 
              KeyedSubtree(
                key: ValueKey('${entry.value.id}_${entry.key}'),
                child: _buildSongTile(entry.value, isPlaying: false, showDragHandle: true, listIndex: entry.key)
                    .animate()
                    .fadeIn(
                      duration: const Duration(milliseconds: 300),
                      delay: Duration(milliseconds: 50 * (entry.key % 10)),
                    )
                    .slideY(begin: 0.1, end: 0, duration: const Duration(milliseconds: 300)),
              )
            ).toList(),
          ),
        ] else if (currentSong != null) ...[
          const Padding(
            padding: EdgeInsets.only(top: 32.0),
            child: Center(
              child: Text('Tidak ada lagu selanjutnya', style: TextStyle(color: Color(0xFF888888))),
            ),
          )
        ]
      ],
    );
  }

  Widget _buildHistoryList(List<SongModel> history) {
    if (history.isEmpty) {
      return const Center(child: Text('Belum ada riwayat pemutaran'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: history.length,
      itemBuilder: (context, index) {
        return _buildSongTile(history[index], isHistory: true)
            .animate()
            .fadeIn(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: 50 * (index % 10)),
            )
            .slideY(begin: 0.1, end: 0, duration: const Duration(milliseconds: 300));
      },
    );
  }

  Widget _buildSongTile(SongModel song, {bool isPlaying = false, bool isHistory = false, int? listIndex, bool showDragHandle = false}) {
    final bool isOnline = song.data.startsWith('online:');
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () {
        if (isHistory) {
          ref.read(audioHandlerProvider.notifier).playSong(song);
        } else if (!isPlaying && listIndex != null) {
          final audioNotifier = ref.read(audioHandlerProvider.notifier);
          final queueIndex = audioNotifier.currentIndex + 1 + listIndex;
          audioNotifier.seek(Duration.zero, index: queueIndex);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          children: [
            if (showDragHandle) ...[
              ReorderableDragStartListener(
                index: listIndex!,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 20,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ],
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.muted,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: isOnline
                  ? Image.network(song.uri ?? '', fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.music_note, color: theme.colorScheme.primary))
                  : Icon(Icons.music_note, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.w500,
                      color: isPlaying ? theme.colorScheme.primary : theme.colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (isOnline)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(Icons.cloud_queue, size: 12, color: theme.colorScheme.mutedForeground),
                        ),
                      Expanded(
                        child: Text(
                          song.artist ?? 'Unknown Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isPlaying)
              Icon(Icons.volume_up, color: theme.colorScheme.primary, size: 20),
            if (isHistory && !isPlaying)
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: () {
                  ref.read(audioHandlerProvider.notifier).playSong(song);
                },
              ),
          ],
        ),
      ),
    );
  }
}