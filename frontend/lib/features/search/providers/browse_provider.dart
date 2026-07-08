import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/online_song_model.dart';

/// A single genre section with its songs
class GenreSection {
  final String title;
  final String query;
  final List<OnlineSongModel> songs;
  final bool isLoading;
  final String? error;

  const GenreSection({
    required this.title,
    required this.query,
    this.songs = const [],
    this.isLoading = false,
    this.error,
  });

  GenreSection copyWith({
    List<OnlineSongModel>? songs,
    bool? isLoading,
    String? error,
  }) {
    return GenreSection(
      title: title,
      query: query,
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// State for the browse/explore screen
class BrowseState {
  final List<GenreSection> sections;
  final bool isInitialized;

  const BrowseState({
    this.sections = const [],
    this.isInitialized = false,
  });

  BrowseState copyWith({
    List<GenreSection>? sections,
    bool? isInitialized,
  }) {
    return BrowseState(
      sections: sections ?? this.sections,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class BrowseNotifier extends StateNotifier<BrowseState> {
  BrowseNotifier() : super(const BrowseState());

  // ═══════════════════════════════════════════════════════════════
  //  Algorithm: "Locale-Aware Editorial Curation + Randomized Rotation"
  //
  //  1. UNIVERSAL POOL: Genre sections that work globally regardless
  //     of region — keywords in English since YouTube search is
  //     English-friendly worldwide.
  //
  //  2. REGIONAL POOL: Locale-specific sections detected from
  //     the device's language/country code. Each region gets 2-3
  //     local genre entries injected into the pool.
  //
  //  3. SHUFFLE + PICK: The combined pool is shuffled each session
  //     and 6 sections are selected for display — guaranteeing
  //     variety while always including some local flavor.
  //
  //  Reference: This mirrors Spotify's "Browse" algorithm which
  //  combines global editorial playlists with locale-specific
  //  content based on the user's market/region setting.
  // ═══════════════════════════════════════════════════════════════

  /// Universal genres — language/region agnostic
  static const List<Map<String, String>> _universalPool = [
    {'title': '🔥 Trending Now',      'query': 'top hits 2025 trending music'},
    {'title': '🎵 Pop Hits',          'query': 'pop hits best songs'},
    {'title': '🎸 Rock Anthems',      'query': 'rock anthems greatest hits'},
    {'title': '🎹 Acoustic & Chill',  'query': 'acoustic chill relaxing songs'},
    {'title': '🎷 Jazz Vibes',        'query': 'jazz smooth vibes playlist'},
    {'title': '🎧 EDM & Dance',       'query': 'EDM dance party hits mix'},
    {'title': '💜 R&B Soul',          'query': 'r&b soul hits best'},
    {'title': '🎤 Hip-Hop',           'query': 'hip hop rap hits'},
    {'title': '🎻 Classical',         'query': 'classical music best pieces'},
    {'title': '🌙 Lo-Fi Beats',       'query': 'lofi hip hop beats chill'},
    {'title': '💪 Workout Energy',    'query': 'workout music energy motivation'},
    {'title': '🎸 Indie Picks',       'query': 'indie music best songs'},
  ];

  /// Regional genre pools — keyed by language code (ISO 639-1)
  /// Each region gets local-flavor sections with native-language keywords
  static const Map<String, List<Map<String, String>>> _regionalPools = {
    // ─── Indonesian (id) ───
    'id': [
      {'title': '🇮🇩 Hits Indonesia',    'query': 'lagu indonesia terbaru hits'},
      {'title': '🎶 Pop Indonesia',       'query': 'pop indonesia populer'},
      {'title': '🎵 Dangdut Viral',       'query': 'dangdut viral terbaru'},
    ],
    // ─── Japanese (ja) ───
    'ja': [
      {'title': '🇯🇵 J-Pop Hits',        'query': 'jpop hits 人気曲'},
      {'title': '🎌 Anime Songs',         'query': 'anime opening songs best'},
      {'title': '🎵 Japanese Rock',       'query': 'japanese rock jrock hits'},
    ],
    // ─── Korean (ko) ───
    'ko': [
      {'title': '🇰🇷 K-Pop Hits',        'query': 'kpop hits 인기곡'},
      {'title': '🎤 K-R&B',              'query': 'korean r&b songs best'},
      {'title': '🎵 K-Hip-Hop',          'query': 'korean hip hop khiphop'},
    ],
    // ─── Spanish (es) ───
    'es': [
      {'title': '🇪🇸 Latin Hits',        'query': 'latin music reggaeton hits'},
      {'title': '🎵 Pop Latino',          'query': 'pop latino exitos'},
      {'title': '🎤 Música Urbana',       'query': 'musica urbana trap latino'},
    ],
    // ─── Portuguese (pt) ───
    'pt': [
      {'title': '🇧🇷 Funk & Sertanejo',  'query': 'funk sertanejo hits brasil'},
      {'title': '🎵 MPB',                 'query': 'mpb musica popular brasileira'},
      {'title': '🎤 Pop Brasil',          'query': 'pop brasileiro hits'},
    ],
    // ─── Hindi (hi) ───
    'hi': [
      {'title': '🇮🇳 Bollywood Hits',    'query': 'bollywood hits songs'},
      {'title': '🎵 Hindi Pop',           'query': 'hindi pop songs latest'},
      {'title': '🎤 Punjabi Beats',       'query': 'punjabi songs hits'},
    ],
    // ─── Thai (th) ───
    'th': [
      {'title': '🇹🇭 เพลงไทยฮิต',       'query': 'เพลงไทย ฮิต'},
      {'title': '🎵 Thai Pop',            'query': 'thai pop hits songs'},
      {'title': '🎤 Luk Thung',           'query': 'ลูกทุ่ง เพลงใหม่'},
    ],
    // ─── Chinese (zh) ───
    'zh': [
      {'title': '🇨🇳 华语热歌',           'query': '华语流行歌曲 热门'},
      {'title': '🎵 Mandopop',            'query': 'mandopop hits chinese pop'},
      {'title': '🎤 C-Pop Trending',      'query': 'cpop trending 流行'},
    ],
    // ─── Arabic (ar) ───
    'ar': [
      {'title': '🎵 Arabic Hits',         'query': 'arabic music hits أغاني'},
      {'title': '🎤 Khaliji',             'query': 'khaliji music خليجي'},
    ],
    // ─── German (de) ───
    'de': [
      {'title': '🇩🇪 Deutsche Hits',     'query': 'deutsche musik hits'},
      {'title': '🎵 Schlager',            'query': 'schlager hits deutsch'},
    ],
    // ─── French (fr) ───
    'fr': [
      {'title': '🇫🇷 Musique Française', 'query': 'musique francaise hits'},
      {'title': '🎵 Rap FR',              'query': 'rap francais hits'},
    ],
    // ─── Malay (ms) ───
    'ms': [
      {'title': '🇲🇾 Lagu Melayu',       'query': 'lagu melayu terbaru hits'},
      {'title': '🎵 Nasyid',              'query': 'nasyid popular terbaru'},
    ],
    // ─── Filipino/Tagalog (tl) ───
    'tl': [
      {'title': '🇵🇭 OPM Hits',          'query': 'OPM hits songs Filipino'},
      {'title': '🎵 Pinoy Pop',           'query': 'pinoy pop songs latest'},
    ],
    // ─── Vietnamese (vi) ───
    'vi': [
      {'title': '🇻🇳 V-Pop Hits',        'query': 'vpop nhạc việt hot'},
      {'title': '🎵 Nhạc Trẻ',            'query': 'nhạc trẻ hay nhất'},
    ],
    // ─── Turkish (tr) ───
    'tr': [
      {'title': '🇹🇷 Türkçe Pop',        'query': 'türkçe pop hit şarkılar'},
      {'title': '🎵 Arabesk',             'query': 'arabesk müzik hit'},
    ],
    // ─── Russian (ru) ───
    'ru': [
      {'title': '🇷🇺 Русские Хиты',      'query': 'русская музыка хиты'},
      {'title': '🎵 Russian Pop',          'query': 'russian pop hits'},
    ],
  };

  /// Detect the device language code (ISO 639-1, e.g. "id", "en", "ja")
  static String _detectLanguageCode() {
    try {
      // Platform.localeName returns e.g. "id_ID", "en_US", "ja_JP"
      final localeName = Platform.localeName;
      // Extract the language part (before underscore or hyphen)
      final lang = localeName.split(RegExp(r'[_\-]')).first.toLowerCase();
      return lang;
    } catch (_) {
      return 'en'; // Fallback to English
    }
  }

  /// Build the combined genre pool based on device locale
  static List<Map<String, String>> _buildGenrePool() {
    final langCode = _detectLanguageCode();

    // Start with all universal genres
    final pool = List<Map<String, String>>.from(_universalPool);

    // Add region-specific genres if available
    if (_regionalPools.containsKey(langCode)) {
      pool.addAll(_regionalPools[langCode]!);
    }

    return pool;
  }

  /// Initialize browse sections with shuffled genres
  Future<void> initialize({bool forceRefresh = false}) async {
    if (state.isInitialized && !forceRefresh) return;

    // Build locale-aware genre pool
    final pool = _buildGenrePool();

    // Shuffle for variety each session (like Spotify's daily rotation)
    pool.shuffle();

    // Take first 6 genres for display
    final selectedGenres = pool.take(6).toList();

    final sections = selectedGenres
        .map((g) => GenreSection(
              title: g['title']!,
              query: g['query']!,
              isLoading: true,
            ))
        .toList();

    state = BrowseState(sections: sections, isInitialized: true);

    // Fetch sections sequentially to avoid spamming the API / rate limits
    // Since the user's connection or the backend might be slow, doing 6 concurrent requests
    // often causes timeouts or 'Too Many Requests' errors.
    for (int i = 0; i < sections.length; i++) {
      await _fetchSection(i, sections[i].query);
      // Add a small delay between requests to be safe
      if (i < sections.length - 1) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
  }

  /// Fetch songs for a specific section index
  Future<void> _fetchSection(int index, String query) async {
    try {
      final response = await DioClient.instance.get(
        '/search',
        queryParameters: {'q': query},
      );

      final List<dynamic> results = response.data['results'];
      final songs = results.map((e) => OnlineSongModel.fromJson(e)).toList();

      // Update only this section's songs
      final updatedSections = List<GenreSection>.from(state.sections);
      updatedSections[index] = updatedSections[index].copyWith(
        songs: songs,
        isLoading: false,
      );
      state = state.copyWith(sections: updatedSections);
    } catch (e) {
      final updatedSections = List<GenreSection>.from(state.sections);
      updatedSections[index] = updatedSections[index].copyWith(
        isLoading: false,
        error: e.toString(),
      );
      state = state.copyWith(sections: updatedSections);
    }
  }

  /// Retry a failed section
  Future<void> retrySection(int index) async {
    final updatedSections = List<GenreSection>.from(state.sections);
    updatedSections[index] = updatedSections[index].copyWith(
      isLoading: true,
      error: null,
    );
    state = state.copyWith(sections: updatedSections);
    await _fetchSection(index, state.sections[index].query);
  }
}

final browseProvider = StateNotifierProvider<BrowseNotifier, BrowseState>((ref) {
  return BrowseNotifier();
});
