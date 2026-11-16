import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import 'models.dart';

/// Backend mobile endpoints. All requests go through ApiClient, which
/// attaches the bearer token and role headers.
class SessionService {
  SessionService(this._client);

  final ApiClient _client;

  /// GET /api/mobile/session — identity + available memberships.
  Future<SessionInfo> fetchSession() async {
    final Response<Map<String, dynamic>> res;
    try {
      res = await _client.get<Map<String, dynamic>>('/api/mobile/session');
    } on DioException catch (e) {
      throw _mapDio(e);
    }
    final body = res.data ?? const <String, dynamic>{};
    if (body['ok'] != true) {
      throw ApiException(
        body['message'] as String? ?? 'Session lookup failed.',
        res.statusCode,
      );
    }
    return SessionInfo.fromJson(body);
  }

  /// GET /api/worklog/state?scope=me — the signed-in employee's snapshot.
  Future<Map<String, dynamic>> fetchWorklogState() async {
    final Response<Map<String, dynamic>> res;
    try {
      res = await _client.get<Map<String, dynamic>>(
        '/api/worklog/state',
        query: {'scope': 'me'},
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
    final body = res.data;
    if (body is! Map<String, dynamic>) {
      throw ApiException('Unexpected response from server.', res.statusCode);
    }
    return body;
  }

  /// POST /api/mobile/onboarding — self-service staff registration.
  /// Same backend rules as web /onboarding; returns the new membership + state.
  Future<Map<String, dynamic>> completeOnboarding({
    required String workArrangement,
    String? clientOrganisationId,
    String? jobTitle,
    String? department,
  }) async {
    final Response<Map<String, dynamic>> res;
    try {
      res = await _client.post<Map<String, dynamic>>(
        '/api/mobile/onboarding',
        data: {
          'workArrangement': workArrangement,
          'clientOrganisationId': ?clientOrganisationId,
          'jobTitle': ?jobTitle,
          'department': ?department,
        },
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
    final body = res.data ?? const <String, dynamic>{};
    if (body['ok'] != true) {
      throw ApiException(body['message'] as String? ?? 'Registration failed.', res.statusCode);
    }
    return body;
  }

  /// POST /api/mobile/invitations/redeem — prepared for the future
  /// invitation flow; not invoked by the current UI.
  Future<Map<String, dynamic>> redeemInvitation(
    String invitationToken, {
    String? graphAccessToken,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/api/mobile/invitations/redeem',
      data: {
        'token': invitationToken,
        'graphAccessToken': ?graphAccessToken,
      },
    );
    final body = res.data;
    return body is Map<String, dynamic> ? body : {'ok': false};
  }
}

class ApiException implements Exception {
  ApiException(this.message, this.statusCode);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

ApiException _mapDio(DioException e) {
  final status = e.response?.statusCode;
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return ApiException('Cannot reach the WorkTrack server. Check your connection.', null);
  }
  final body = e.response?.data;
  final message = body is Map<String, dynamic>
      ? (body['message'] as String? ?? body['error'] as String?)
      : null;
  return ApiException(message ?? 'Request failed (${status ?? 'network error'}).', status);
}
