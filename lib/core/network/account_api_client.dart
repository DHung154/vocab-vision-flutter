import 'dart:convert';
import 'dart:io';

/// DTOs and a small HTTP boundary for optional account/sync support.
///
/// The app never requires this client to open: guest learning, the release
/// catalog and E4 recognition remain local. A configured API is used only
/// after the learner explicitly signs in.
class AccountUser {
  final String id;
  final String email;
  final String displayName;
  final String createdAt;
  final String updatedAt;
  final String role;

  const AccountUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.role = 'learner',
  });

  factory AccountUser.fromJson(Map<String, dynamic> json) => AccountUser(
    id: _requiredString(json, 'id'),
    email: _requiredString(json, 'email'),
    displayName: _requiredString(json, 'display_name'),
    createdAt: _requiredString(json, 'created_at'),
    updatedAt: _requiredString(json, 'updated_at'),
    role: json['role'] is String && (json['role'] as String).isNotEmpty
        ? json['role'] as String
        : 'learner',
  );

  Map<String, String> toJson() => {
    'id': id,
    'email': email,
    'display_name': displayName,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'role': role,
  };
}

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String accessExpiresAt;
  final String refreshExpiresAt;
  final AccountUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    if (rawUser is! Map) {
      throw const FormatException('Account response thiếu user');
    }
    return AuthSession(
      accessToken: _requiredString(json, 'access_token'),
      refreshToken: _requiredString(json, 'refresh_token'),
      accessExpiresAt: _requiredString(json, 'access_expires_at'),
      refreshExpiresAt: _requiredString(json, 'refresh_expires_at'),
      user: AccountUser.fromJson(Map<String, dynamic>.from(rawUser)),
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_expires_at': accessExpiresAt,
    'refresh_expires_at': refreshExpiresAt,
    'user': user.toJson(),
  };
}

class SyncPullPage {
  final int cursor;
  final bool hasMore;
  final List<Map<String, dynamic>> events;

  const SyncPullPage({
    required this.cursor,
    required this.hasMore,
    required this.events,
  });
}

class AccountApiClient {
  final String baseUrl;
  final HttpClient _client;

  AccountApiClient(this.baseUrl, {HttpClient? client})
    : _client = client ?? HttpClient();

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await _send(
      method: 'POST',
      path: '/api/v1/auth/register',
      body: {'email': email, 'password': password, 'display_name': displayName},
    );
    return AuthSession.fromJson(response);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(
      method: 'POST',
      path: '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(response);
  }

  Future<String?> requestPasswordReset({required String email}) async {
    final response = await _send(
      method: 'POST',
      path: '/api/v1/auth/password-reset/request',
      body: {'email': email},
    );
    final token = response['dev_token'];
    return token is String && token.trim().isNotEmpty ? token : null;
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String password,
  }) async {
    await _send(
      method: 'POST',
      path: '/api/v1/auth/password-reset/confirm',
      body: {'token': token, 'password': password},
    );
  }

  Future<Map<String, dynamic>> exportAccount({required String accessToken}) =>
      _send(method: 'GET', path: '/api/v1/me/export', accessToken: accessToken);

  Future<AccountUser> updateProfile({
    required String accessToken,
    required String displayName,
  }) async {
    final response = await _send(
      method: 'PATCH',
      path: '/api/v1/me',
      accessToken: accessToken,
      body: {'display_name': displayName.trim()},
    );
    final rawUser = response['user'];
    if (rawUser is! Map) {
      throw const FormatException('Account response thiếu user');
    }
    return AccountUser.fromJson(Map<String, dynamic>.from(rawUser));
  }

  Future<void> deleteAccount({
    required String accessToken,
    required String password,
  }) async {
    await _send(
      method: 'DELETE',
      path: '/api/v1/me',
      accessToken: accessToken,
      body: {'password': password},
      allowEmpty: true,
    );
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _send(
      method: 'POST',
      path: '/api/v1/auth/refresh',
      body: {'refresh_token': refreshToken},
    );
    return AuthSession.fromJson(response);
  }

  Future<void> logout(String accessToken) async {
    await _send(
      method: 'POST',
      path: '/api/v1/auth/logout',
      accessToken: accessToken,
      allowEmpty: true,
    );
  }

  Future<List<String>> pushEvents({
    required String accessToken,
    required List<Map<String, dynamic>> events,
  }) async {
    if (events.isEmpty) return const [];
    final response = await _send(
      method: 'POST',
      path: '/api/v1/sync/push',
      accessToken: accessToken,
      body: {'events': events},
    );
    final acknowledgements = response['acknowledged'];
    if (acknowledgements is! List) {
      throw const FormatException('Sync response thiếu acknowledged');
    }
    final conflicts = acknowledgements
        .whereType<Map>()
        .where((item) => item['status'] == 'conflict')
        .map((item) => item['event_id'])
        .whereType<String>()
        .toList(growable: false);
    if (conflicts.isNotEmpty) {
      throw StateError(
        'Máy chủ báo xung đột event: ${conflicts.take(3).join(', ')}',
      );
    }
    return acknowledgements
        .whereType<Map>()
        .where(
          (item) =>
              item['status'] == 'accepted' || item['status'] == 'duplicate',
        )
        .map((item) => item['event_id'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  Future<SyncPullPage> pullEvents({
    required String accessToken,
    int cursor = 0,
    int limit = 100,
  }) async {
    final response = await _send(
      method: 'GET',
      path: '/api/v1/sync/pull',
      accessToken: accessToken,
      query: {
        'cursor': '${cursor < 0 ? 0 : cursor}',
        'limit': '${limit.clamp(1, 100)}',
      },
    );
    final rawEvents = response['events'];
    if (rawEvents is! List) {
      throw const FormatException('Sync response thiếu events');
    }
    // The backend calls this value next_cursor; accepting cursor as a
    // compatibility alias keeps the client tolerant of an older API build.
    final rawCursor = response['next_cursor'] ?? response['cursor'];
    return SyncPullPage(
      cursor: rawCursor is int
          ? rawCursor
          : int.tryParse('$rawCursor') ?? cursor,
      hasMore: response['has_more'] == true,
      events: rawEvents
          .whereType<Map>()
          .map((event) => Map<String, dynamic>.from(event))
          .toList(growable: false),
    );
  }

  Future<Map<String, dynamic>> reportContent({
    required String accessToken,
    required String wordId,
    required String reportType,
    required String note,
  }) => _send(
    method: 'POST',
    path: '/api/v1/content-reports',
    accessToken: accessToken,
    body: {'word_id': wordId, 'report_type': reportType, 'note': note},
  );

  Future<List<Map<String, dynamic>>> fetchAdminReports({
    required String accessToken,
    String? status,
    int limit = 100,
  }) async {
    final response = await _send(
      method: 'GET',
      path: '/api/v1/admin/content-reports',
      accessToken: accessToken,
      query: {
        if (status != null && status.trim().isNotEmpty) 'status': status,
        'limit': '${limit.clamp(1, 200)}',
      },
    );
    final reports = response['reports'];
    if (reports is! List) {
      throw const FormatException('Admin response thiếu reports');
    }
    return reports
        .whereType<Map>()
        .map((report) => Map<String, dynamic>.from(report))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> updateAdminReport({
    required String accessToken,
    required String reportId,
    required String status,
  }) => _send(
    method: 'PATCH',
    path: '/api/v1/admin/content-reports/$reportId',
    accessToken: accessToken,
    body: {'status': status},
  );

  Future<List<Map<String, dynamic>>> fetchCatalogReleases({
    required String accessToken,
  }) async {
    final response = await _send(
      method: 'GET',
      path: '/api/v1/catalog/admin/releases',
      accessToken: accessToken,
    );
    final releases = response['releases'];
    if (releases is! List) {
      throw const FormatException('Catalog admin response thiếu releases');
    }
    return releases
        .whereType<Map>()
        .map((release) => Map<String, dynamic>.from(release))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> publishCatalogRelease({
    required String accessToken,
    required Map<String, dynamic> manifest,
  }) => _send(
    method: 'POST',
    path: '/api/v1/catalog/admin/releases/publish',
    accessToken: accessToken,
    body: {'manifest': manifest},
  );

  Future<Map<String, dynamic>> rollbackCatalogRelease({
    required String accessToken,
    required String version,
  }) => _send(
    method: 'POST',
    path:
        '/api/v1/catalog/admin/releases/${Uri.encodeComponent(version)}/rollback',
    accessToken: accessToken,
  );

  Future<Map<String, dynamic>> _send({
    required String method,
    required String path,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? accessToken,
    bool allowEmpty = false,
  }) async {
    final uri = Uri.parse(
      baseUrl,
    ).resolve(path).replace(queryParameters: query);
    final request = await _client
        .openUrl(method, uri)
        .timeout(const Duration(seconds: 8));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (accessToken != null && accessToken.isNotEmpty) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close().timeout(const Duration(seconds: 8));
    final text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Account API ${response.statusCode}', uri: uri);
    }
    if (text.trim().isEmpty && allowEmpty) return const <String, dynamic>{};
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Account response không hợp lệ');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void close() => _client.close(force: true);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Account response thiếu $key');
  }
  return value;
}
