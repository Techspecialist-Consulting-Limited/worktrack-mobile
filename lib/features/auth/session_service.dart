import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../proto/models.dart' show ComplaintFile;
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

  /* ---------------- worklog actions ---------------- */

  /// POST /api/worklog/action — dispatches a mutation and returns the
  /// response body ({ ok, message?, db? } where db is the fresh snapshot).
  Future<Map<String, dynamic>> postAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/api/worklog/action',
        data: {'action': action, 'payload': payload},
      );
      final body = res.data ?? const <String, dynamic>{};
      return body;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Uploads a pending work-entry evidence file.
  /// Returns the new attachment id, or throws [ApiException].
  Future<String> uploadWorkEntryFile(String path, String fileName) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: fileName),
    });
    try {
      final res = await _client.postMultipart<Map<String, dynamic>>(
        '/api/worklog/attachments',
        form,
      );
      final body = res.data ?? const <String, dynamic>{};
      final att = body['attachment'] as Map<String, dynamic>?;
      final id = att?['id'] as String?;
      if (body['ok'] != true || id == null) {
        throw ApiException(body['message'] as String? ?? 'Upload failed.', res.statusCode);
      }
      return id;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /* ---------------- complaints ---------------- */

  /// GET /api/complaints — staff receive only their own records.
  Future<List<Map<String, dynamic>>> fetchComplaints() async {
    try {
      final res = await _client.get<Map<String, dynamic>>('/api/complaints');
      final body = res.data ?? const <String, dynamic>{};
      final list = body['complaints'] as List? ?? const [];
      return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// POST /api/complaints — multipart when files are attached.
  Future<Map<String, dynamic>> createComplaint({
    required String subject,
    required String description,
    List<ComplaintFile> files = const [],
  }) async {
    final withPaths = files.where((f) => f.path != null).toList();
    try {
      if (withPaths.isEmpty) {
        final res = await _client.post<Map<String, dynamic>>(
          '/api/complaints',
          data: {'subject': subject, 'description': description},
        );
        return res.data ?? const <String, dynamic>{};
      }
      final form = FormData.fromMap({
        'subject': subject,
        'description': description,
        'files': [
          for (final f in withPaths)
            await MultipartFile.fromFile(f.path!, filename: f.fileName),
        ],
      });
      final res = await _client.postMultipart<Map<String, dynamic>>('/api/complaints', form);
      return res.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Uploads a pending complaint attachment (reply flow). Returns its id.
  Future<String> uploadComplaintFile(String complaintId, String path, String fileName) async {
    final form = FormData.fromMap({
      'complaintId': complaintId,
      'file': await MultipartFile.fromFile(path, filename: fileName),
    });
    try {
      final res = await _client.postMultipart<Map<String, dynamic>>(
        '/api/complaints/attachments',
        form,
      );
      final body = res.data ?? const <String, dynamic>{};
      final att = body['attachment'] as Map<String, dynamic>?;
      final id = att?['id'] as String?;
      if (body['ok'] != true || id == null) {
        throw ApiException(body['message'] as String? ?? 'Upload failed.', res.statusCode);
      }
      return id;
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// POST /api/complaints/[id] — staff reply or mark-read.
  Future<Map<String, dynamic>> complaintAction(
    String complaintId, {
    String type = 'reply',
    String? body,
    List<String> attachmentIds = const [],
  }) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/api/complaints/$complaintId',
        data: {
          'type': type,
          'body': ?body,
          if (attachmentIds.isNotEmpty) 'attachmentIds': attachmentIds,
        },
      );
      return res.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// GET /api/mobile/onboarding — active client organisations for the
  /// self-service client-site picker (no membership required).
  Future<List<Map<String, dynamic>>> fetchClientOrganisations() async {
    try {
      final res = await _client.get<Map<String, dynamic>>('/api/mobile/onboarding');
      final body = res.data ?? const <String, dynamic>{};
      final list = body['clientOrganisations'] as List? ?? const [];
      return list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  /// Redeems a prepared invitation (kept for the invitation flow).
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
