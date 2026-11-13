import 'package:dio/dio.dart';

/// HTTP client for the WorkTrack API. Attaches the Entra bearer token and
/// the selected role header; never logs token material.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.accessToken,
    required this.role,
    this.onUnauthorized,
  }) : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        ));

  final Dio dio;
  final String baseUrl;

  /// Current WorkTrack API access token (never persisted by this class).
  final String Function() accessToken;

  /// Currently selected WorkTrack role, sent as `x-worktrack-role`.
  final String? Function() role;

  /// Called once on a 401 to attempt silent token renewal.
  /// Return a fresh token, or null to propagate the 401.
  final Future<String?> Function()? onUnauthorized;

  Future<Response<T>> _send<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && onUnauthorized != null) {
        final fresh = await onUnauthorized!();
        if (fresh != null) {
          return call();
        }
      }
      rethrow;
    }
  }

  Options _options() => Options(headers: _headers());

  Map<String, String> _headers() {
    final headers = <String, String>{'Authorization': 'Bearer ${accessToken()}'};
    final r = role();
    if (r != null && r.isNotEmpty) headers['x-worktrack-role'] = r;
    return headers;
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get<T>(path, queryParameters: query, options: _options()));

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _send(() => dio.post<T>(path, data: data, options: _options()));
}
