import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/artist_profile_model.dart';
import '../../../core/network/dio_client.dart';

class ArtistRepository {
  Future<ArtistProfileModel> getArtistProfile(String artistName) async {
    try {
      final response = await DioClient.instance.get(
        '/artist/${Uri.encodeComponent(artistName)}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'];
        if (data != null) {
          return ArtistProfileModel.fromJson(data);
        }
      }
      throw Exception('Failed to load artist profile');
    } catch (e) {
      throw Exception('Failed to load artist profile: $e');
    }
  }
}

final artistRepositoryProvider = Provider<ArtistRepository>((ref) {
  return ArtistRepository();
});

final artistProfileProvider = FutureProvider.family<ArtistProfileModel, String>((ref, artistName) {
  final repository = ref.watch(artistRepositoryProvider);
  return repository.getArtistProfile(artistName);
});
