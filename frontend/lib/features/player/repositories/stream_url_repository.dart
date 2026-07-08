import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class StreamUrlRepository {
  Future<String?> getStreamUrl(String source, String reference, {String? mechanism, int? duration}) async {
    try {
      final Map<String, dynamic> params = {
        'source': source,
        'reference': reference,
      };
      if (mechanism != null && mechanism.isNotEmpty) {
        params['stream_mechanism'] = mechanism;
      }
      if (duration != null && duration > 0) {
        params['duration'] = duration;
      }

      final response = await DioClient.instance.get(
        '/stream-url',
        queryParameters: params,
      );

      final data = response.data;
      if (data['error'] != null) {
        throw Exception(data['message'] ?? data['error']);
      }

      return data['stream_url'] as String?;
    } catch (e) {
      // Return null or rethrow, handled by player provider
      rethrow;
    }
  }
}

final streamUrlRepositoryProvider = Provider<StreamUrlRepository>((ref) {
  return StreamUrlRepository();
});
