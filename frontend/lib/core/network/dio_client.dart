import 'package:dio/dio.dart';
import 'auth_service.dart';

class DioClient {
  static late final Dio instance;

  static void initialize() {
    // Karena kita memakai ADB Reverse Port Forwarding,
    const String baseUrl = 'http://127.0.0.1:8000/api';
    //const String baseUrl = 'http://10.0.2.2:8000/api';

    instance = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // ── Auth Interceptor ───────────────────────────────────────────────────
    // Secara otomatis inject Bearer Token ke setiap request,
    // dan handle 401 (token expired/invalid) dengan clear token.
    instance.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthService.instance.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Token expired atau tidak valid — paksa logout
            await AuthService.instance.clearAll();
          }
          return handler.next(e);
        },
      ),
    );

    // ── Logging Interceptor ────────────────────────────────────────────────
    instance.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
      ),
    );
  }
}
