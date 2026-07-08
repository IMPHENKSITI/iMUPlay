// Removed unnecessary material.dart import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/audio/audio_handler.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'core/network/dio_client.dart';
import 'features/home/screens/main_screen.dart';
import 'shared/providers/theme_provider.dart';
import 'features/player/services/audio_session_manager.dart';
import 'core/storage/local_database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize API Client
  DioClient.initialize();
  
  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox<List>('favorites');
  await Hive.openBox<List>('playlists');
  await Hive.openBox<String>('online_playlists'); // We will store JSON string of lists
  await Hive.openBox<String>('cache_metadata'); // Store JSON strings of CacheMetadata
  await Hive.openBox<String>('settings'); // Application settings
  await Hive.openBox<List>('search_history'); // Stores recent search queries

  // Initialize Database
  await LocalDatabaseService.init();

  // Initialize Background Audio
  try {
    await initAudioService();
  } catch (e) {
    debugPrint("AudioService init error: $e");
  }

  // Initialize Audio Session
  await AudioSessionManager.configureSession();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch ThemeProvider
    final appThemeMode = ref.watch(themeProvider);
    
    // Map AppThemeMode enum to flutter's ThemeMode enum
    final ThemeMode mode;
    switch (appThemeMode) {
      case AppThemeMode.light:
        mode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        mode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        mode =  ThemeMode.system;
        break;
    }

    return ShadcnApp(
      debugShowCheckedModeBanner: false,
      title: 'Music Player',
      themeMode: mode,
      theme: ThemeData(
        colorScheme: ColorSchemes.lightZinc,
        radius: 0.5,
        typography: Typography.geist(
          sans: GoogleFonts.plusJakartaSans(),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorSchemes.darkZinc,
        radius: 0.5,
        typography: Typography.geist(
          sans: GoogleFonts.plusJakartaSans(),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
