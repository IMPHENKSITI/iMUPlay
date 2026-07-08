
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/online_song_model.dart';

class OnlineSearchNotifier extends StateNotifier<AsyncValue<List<OnlineSongModel>>> {
  OnlineSearchNotifier() : super(const AsyncValue.data([]));

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final response = await DioClient.instance.get(
        '/search',
        queryParameters: {'q': query},
      );

      final List<dynamic> results = response.data['results'];
      final songs = results.map((e) => OnlineSongModel.fromJson(e)).toList();
      
      state = AsyncValue.data(songs);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

final onlineSearchProvider = StateNotifierProvider<OnlineSearchNotifier, AsyncValue<List<OnlineSongModel>>>((ref) {
  return OnlineSearchNotifier();
});
