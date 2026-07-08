import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/services/audio_cache_manager.dart'; 
import '../../player/services/audio_session_manager.dart';
import '../../../shared/providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _cacheSizeBytes = 0;
  bool _isLoadingCache = true;
  int _focusPreference = 0;

  @override
  void initState() {
    super.initState();
    _focusPreference = AudioSessionManager.focusPreference;
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    setState(() => _isLoadingCache = true);
    try {
      final dir = await AudioCacheManager.getCacheDirectory();
      final List<FileSystemEntity> files = await dir.list().toList();
      int totalSize = 0;
      for (var file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      setState(() {
        _cacheSizeBytes = totalSize;
        _isLoadingCache = false;
      });
    } catch (e) {
      setState(() => _isLoadingCache = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (log(bytes) / log(1024)).floor();
    if (i >= suffixes.length) i = suffixes.length - 1;
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _showFocusPreferenceDialog() {
    showDialog(
      context: context,
      builder: (context) {
        int selected = _focusPreference;
        return AlertDialog(
          title: const Text('Fokus Suara'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setDialogState(() => selected = 0),
                    behavior: HitTestBehavior.translucent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Radio(value: selected == 0),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Abaikan Aplikasi Lain', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text('Selalu menjaga musik diputar di latar belakang', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setDialogState(() => selected = 1),
                    behavior: HitTestBehavior.translucent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Radio(value: selected == 1),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hormati Aplikasi Lain', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text('Jeda otomatis ketika aplikasi lain membuat suara', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            PrimaryButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() => _focusPreference = selected);
                AudioSessionManager.setFocusPreference(selected);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showThemeDialog(AppThemeMode currentTheme) {
    showDialog(
      context: context,
      builder: (context) {
        AppThemeMode selected = currentTheme;
        return AlertDialog(
          title: const Text('Tema Aplikasi'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setDialogState(() => selected = AppThemeMode.system),
                    behavior: HitTestBehavior.translucent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Radio(value: selected == AppThemeMode.system),
                          const SizedBox(width: 12),
                          const Text('Mengikuti Sistem', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setDialogState(() => selected = AppThemeMode.light),
                    behavior: HitTestBehavior.translucent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Radio(value: selected == AppThemeMode.light),
                          const SizedBox(width: 12),
                          const Text('Terang (Light)', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => setDialogState(() => selected = AppThemeMode.dark),
                    behavior: HitTestBehavior.translucent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Radio(value: selected == AppThemeMode.dark),
                          const SizedBox(width: 12),
                          const Text('Gelap (Dark)', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            OutlineButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            PrimaryButton(
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(themeProvider.notifier).setTheme(selected);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  String _getThemeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Mengikuti Sistem';
      case AppThemeMode.light:
        return 'Terang (Light)';
      case AppThemeMode.dark:
        return 'Gelap (Dark)';
    }
  }

  Future<void> _clearCache() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Cache Pemutar'),
        content: const Text('Apakah kamu yakin ingin menghapus semua cache pemutar musik? Musik yang diputar offline akan membutuhkan koneksi internet lagi.'),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          DestructiveButton(
            onPressed: () async {
              Navigator.of(context).pop();
              setState(() => _isLoadingCache = true);
              final dir = await AudioCacheManager.getCacheDirectory();
              if (await dir.exists()) {
                await dir.delete(recursive: true);
                await dir.create();
              }
              await _calculateCacheSize();
            },
            child: const Text('Hapus Cache'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Pengaturan'),
        ),
      ],
      child: material.ListView(
        padding: const material.EdgeInsets.all(24.0),
        children: [
          _buildSectionTitle('TAMPILAN'),
          _buildSettingTile(
            title: 'Tema Aplikasi',
            subtitle: _getThemeName(currentTheme),
            icon: material.Icons.palette_outlined,
            onTap: () => _showThemeDialog(currentTheme),
          ),
          
          const material.SizedBox(height: 32),
          _buildSectionTitle('PEMUTARAN'),
          _buildSettingTile(
            title: 'Fokus Suara',
            subtitle: _focusPreference == 0
                ? 'Abaikan aplikasi lain'
                : 'Hormati aplikasi lain',
            icon: material.Icons.volume_up_outlined,
            onTap: _showFocusPreferenceDialog,
          ),
          
          const material.SizedBox(height: 32),
          _buildSectionTitle('PENYIMPANAN'),
          _buildSettingTile(
            title: 'Hapus Cache Pemutar',
            subtitle: _isLoadingCache 
                ? 'Menghitung...' 
                : 'Maks 2 GB • Terpakai ${_formatBytes(_cacheSizeBytes)}',
            icon: material.Icons.storage_rounded,
            onTap: _clearCache,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return material.Padding(
      padding: const material.EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const material.TextStyle(
          fontSize: 12,
          fontWeight: material.FontWeight.w700,
          letterSpacing: 1.2,
          color: material.Color(0xFF888888),
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required material.IconData icon,
    required material.VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return material.InkWell(
      onTap: onTap,
      borderRadius: material.BorderRadius.circular(12),
      child: material.Padding(
        padding: const material.EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: material.Row(
          children: [
            material.Icon(icon, size: 28, color: isDestructive ? material.Colors.redAccent : null),
            const material.SizedBox(width: 16),
            material.Expanded(
              child: material.Column(
                crossAxisAlignment: material.CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: material.TextStyle(
                      fontSize: 16,
                      fontWeight: material.FontWeight.w600,
                      color: isDestructive ? material.Colors.redAccent : null,
                    ),
                  ),
                  const material.SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const material.TextStyle(
                      fontSize: 13,
                      color: material.Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
