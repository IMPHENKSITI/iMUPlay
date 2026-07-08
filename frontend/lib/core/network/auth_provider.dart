import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../network/dio_client.dart';
import '../network/auth_service.dart';
import '../../features/player/providers/audio_player_provider.dart';

// ── State Model ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? userName;
  final String? userEmail;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.isLoading = false,
    this.userName,
    this.userEmail,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isLoading,
    String? userName,
    String? userEmail,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isLoading: isLoading ?? this.isLoading,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AuthState()) {
    _checkLoginStatus();
  }

  final _dio = DioClient.instance;
  final _authService = AuthService.instance;

  /// Cek apakah ada token tersimpan saat app dibuka
  Future<void> _checkLoginStatus() async {
    final hasToken = await _authService.hasToken();
    if (hasToken) {
      final user = await _authService.getUser();
      state = state.copyWith(
        isLoggedIn: true,
        userName: user['name'],
        userEmail: user['email'],
      );
    }
  }

  /// Register user baru
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
      await _saveSession(response.data);
      return true;
    } on DioException catch (e) {
      final msg = _parseError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Login dengan email & password
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      await _saveSession(response.data);
      return true;
    } on DioException catch (e) {
      final msg = _parseError(e);
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  /// Logout — hapus token di server & lokal, serta bersihkan state online
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    // Hentikan lagu yang sedang diputar (agar mini player hilang & tidak ada yang nyangkut)
    try {
      await ref.read(audioHandlerProvider.notifier).stopPlayback();
    } catch (_) {}

    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // Tetap lanjut logout lokal meski server error
    }
    
    // Hapus sesi lokal
    await _authService.clearAll();
    
    // Hapus cache online
    try {
      await Hive.box<String>('online_playlists').clear();
      await Hive.box<List>('search_history').clear();
    } catch (e) {
      // Abaikan jika box belum terbuka
    }

    // Reset state
    state = const AuthState();
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user  = data['user'] as Map<String, dynamic>;

    await _authService.saveToken(token);
    await _authService.saveUser(
      id:    user['id'] as int,
      name:  user['name'] as String,
      email: user['email'] as String,
    );

    state = state.copyWith(
      isLoggedIn: true,
      isLoading: false,
      userName:  user['name'] as String,
      userEmail: user['email'] as String,
    );
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      // Laravel validation errors
      if (data['errors'] != null) {
        final errors = data['errors'] as Map;
        return errors.values.first[0] as String;
      }
      if (data['message'] != null) return data['message'] as String;
    }
    return 'Terjadi kesalahan jaringan. Periksa koneksi Anda.';
  }
}
