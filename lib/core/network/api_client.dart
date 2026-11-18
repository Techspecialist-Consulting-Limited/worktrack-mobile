import 'package:dio/dio.dart';

/// Dev-safe request diagnostics — logs method/path/status only, never
/// headers or token material.
void _logApi(String message) {
  // ignore: avoid_print
  print('[api] $message');
}

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

  Future<Response<T>> _send<T>(Future<Response<T>> Function() call,
      {required String method, required String path}) async {
    try {
      final res = await call();
      _logApi('$method $path -> ${res.statusCode}');
      return res;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      _logApi('$method $path -> ${status ?? e.type.name} (${e.message ?? ''})');
      if (status == 401 && onUnauthorized != null) {
        _logApi('$method $path -> 401, attempting silent renewal');
        final fresh = await onUnauthorized!();
        if (fresh != null) {
          try {
            final res = await call();
            _logApi('$method $path -> retry ${res.statusCode}');
            return res;
          } on DioException catch (e2) {
            _logApi('$method $path -> retry failed ${e2.response?.statusCode ?? e2.type.name}');
            rethrow;
          }
        }
        _logApi('$method $path -> silent renewal unavailable');
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
      _send(() => dio.get<T>(path, queryParameters: query, options: _options()),
          method: 'GET', path: path);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _send(() => dio.post<T>(path, data: data, options: _options()),
          method: 'POST', path: path);

  /// Multipart upload (file evidence). Auth/role headers are attached the
  /// same way as JSON calls; Dio sets the multipart content-type itself.
  Future<Response<T>> postMultipart<T>(String path, FormData data) =>
      _send(() => dio.post<T>(path, data: data, options: _options()),
          method: 'POST', path: '$path (multipart)');
}
