import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/core/network/account_api_client.dart';

void main() {
  test('auth session round-trips the server payload without losing fields', () {
    final session = AuthSession.fromJson({
      'access_token': 'access-token',
      'refresh_token': 'refresh-token',
      'access_expires_at': '2026-09-18T10:00:00+00:00',
      'refresh_expires_at': '2026-10-18T10:00:00+00:00',
      'user': {
        'id': 'user-1',
        'email': 'learner@example.com',
        'display_name': 'Bo',
        'created_at': '2026-09-18T09:00:00+00:00',
        'updated_at': '2026-09-18T09:00:00+00:00',
        'role': 'admin',
      },
    });

    final restored = AuthSession.fromJson(session.toJson());
    expect(restored.accessToken, 'access-token');
    expect(restored.user.email, 'learner@example.com');
    expect(restored.user.displayName, 'Bo');
    expect(restored.user.role, 'admin');
  });

  test('invalid account payload fails closed', () {
    expect(
      () => AuthSession.fromJson(const <String, dynamic>{}),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'refresh client rotates the session through the auth endpoint',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/v1/auth/refresh');
        final body = await utf8.decoder.bind(request).join();
        expect(body, '{"refresh_token":"old-refresh"}');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
            'access_expires_at': '2026-09-19T10:00:00Z',
            'refresh_expires_at': '2026-10-19T10:00:00Z',
            'user': {
              'id': 'user-1',
              'email': 'learner@example.com',
              'display_name': 'Bo',
              'created_at': '2026-09-18T09:00:00Z',
              'updated_at': '2026-09-18T10:00:00Z',
              'role': 'learner',
            },
          }),
        );
        await request.response.close();
      });
      final client = AccountApiClient(
        'http://${server.address.host}:${server.port}',
      );
      try {
        final session = await client.refresh('old-refresh');
        expect(session.accessToken, 'new-access');
        expect(session.refreshToken, 'new-refresh');
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );

  test('sync client consumes the backend next_cursor contract', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'events': [
            {
              'cursor': 3,
              'event_id': 'e3',
              'event_type': 'learning_attempt',
              'payload': {'word_id': 'pencil'},
              'occurred_at': '2026-09-18T10:00:00Z',
            },
          ],
          'next_cursor': 3,
          'has_more': false,
        }),
      );
      unawaited(request.response.close());
    });
    final client = AccountApiClient(
      'http://${server.address.host}:${server.port}',
    );
    try {
      final page = await client.pullEvents(accessToken: 'token');
      expect(page.cursor, 3);
      expect(page.events.single['event_id'], 'e3');
    } finally {
      client.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test(
    'admin catalog client keeps release history and nested manifest',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seen = <String>[];
      final subscription = server.listen((request) async {
        seen.add('${request.method} ${request.uri.path}');
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/v1/catalog/admin/releases' &&
            request.method == 'GET') {
          request.response.write(
            jsonEncode({
              'releases': [
                {'version': 'admin-1', 'status': 'published', 'word_count': 2},
              ],
            }),
          );
        } else if (request.uri.path.endsWith('/rollback')) {
          await utf8.decoder.bind(request).join();
          request.response.write(
            jsonEncode({
              'version': 'admin-1',
              'status': 'withdrawn',
              'restored_version': 'admin-2',
            }),
          );
        } else {
          final body = await utf8.decoder.bind(request).join();
          expect(body, contains('"version":"admin-2"'));
          request.response.write(
            jsonEncode({'version': 'admin-2', 'word_count': 2}),
          );
        }
        await request.response.close();
      });
      final client = AccountApiClient(
        'http://${server.address.host}:${server.port}',
      );
      try {
        final releases = await client.fetchCatalogReleases(
          accessToken: 'admin-token',
        );
        final result = await client.publishCatalogRelease(
          accessToken: 'admin-token',
          manifest: {
            'version': 'admin-2',
            'words': [
              {'id': 'pencil'},
            ],
          },
        );
        final rollback = await client.rollbackCatalogRelease(
          accessToken: 'admin-token',
          version: 'admin-1',
        );
        expect(releases.single['version'], 'admin-1');
        expect(result['word_count'], 2);
        expect(rollback['restored_version'], 'admin-2');
        expect(seen, contains('GET /api/v1/catalog/admin/releases'));
        expect(seen, contains('POST /api/v1/catalog/admin/releases/publish'));
        expect(
          seen,
          contains('POST /api/v1/catalog/admin/releases/admin-1/rollback'),
        );
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );

  test(
    'password reset client requests and confirms a one-time token',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final seenBodies = <String>[];
      final subscription = server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        seenBodies.add(body);
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/v1/auth/password-reset/request') {
          request.response.write(
            jsonEncode({'accepted': true, 'dev_token': 'reset-token'}),
          );
        } else if (request.uri.path == '/api/v1/auth/password-reset/confirm') {
          request.response.write(jsonEncode({'reset': true}));
        } else if (request.uri.path == '/api/v1/me/export') {
          request.response.write(
            jsonEncode({
              'user': {'email': 'learner@example.com'},
              'sync_events': [
                {'event_id': 'event-1'},
              ],
              'content_reports': <dynamic>[],
            }),
          );
        } else if (request.uri.path == '/api/v1/me' &&
            request.method == 'PATCH') {
          request.response.write(
            jsonEncode({
              'user': {
                'id': 'user-1',
                'email': 'learner@example.com',
                'display_name': 'New name',
                'created_at': '2026-09-18T09:00:00Z',
                'updated_at': '2026-09-18T10:00:00Z',
                'role': 'learner',
              },
            }),
          );
        } else if (request.uri.path == '/api/v1/me' &&
            request.method == 'DELETE') {
          request.response.write(jsonEncode(<String, dynamic>{}));
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.write(jsonEncode({'detail': 'not found'}));
        }
        await request.response.close();
      });
      final client = AccountApiClient(
        'http://${server.address.host}:${server.port}',
      );
      try {
        final token = await client.requestPasswordReset(
          email: 'learner@example.com',
        );
        await client.confirmPasswordReset(
          token: token!,
          password: 'new-password-123',
        );
        final exported = await client.exportAccount(
          accessToken: 'access-token',
        );
        final updated = await client.updateProfile(
          accessToken: 'access-token',
          displayName: 'New name',
        );
        await client.deleteAccount(
          accessToken: 'access-token',
          password: 'new-password-123',
        );
        expect(token, 'reset-token');
        expect(updated.displayName, 'New name');
        expect((exported['sync_events'] as List).single['event_id'], 'event-1');
        expect(seenBodies, contains('{"email":"learner@example.com"}'));
        expect(
          seenBodies,
          contains('{"token":"reset-token","password":"new-password-123"}'),
        );
      } finally {
        client.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
