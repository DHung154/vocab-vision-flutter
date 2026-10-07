import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/catalog_data.dart';
import 'package:giao_dien/core/storage/catalog_media_cache.dart';

void main() {
  test(
    'remote catalog media is cached before a release is usable offline',
    () async {
      final root = await Directory.systemTemp.createTemp('vocab-media-test-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final cache = CatalogMediaCache(root: root);
      addTearDown(() async {
        cache.close();
        await server.close(force: true);
        if (await root.exists()) await root.delete(recursive: true);
      });
      server.listen((request) {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(const [0xff, 0xd8, 0xff, 0xd9]);
        unawaited(request.response.close());
      });

      const bundled = CatalogWord(
        id: 'pencil',
        english: 'Pencil',
        vietnamese: 'Bút chì',
        topic: 'Đồ dùng học tập',
        partOfSpeech: 'noun',
        exampleEnglish: 'Use a pencil.',
        exampleVietnamese: 'Dùng bút chì.',
        imageUrl: 'assets/catalog/e4/pencil.jpg',
      );
      final remote = bundled.copyWith();
      final remoteWithUrl = CatalogWord(
        id: remote.id,
        english: remote.english,
        vietnamese: remote.vietnamese,
        topic: remote.topic,
        partOfSpeech: remote.partOfSpeech,
        exampleEnglish: remote.exampleEnglish,
        exampleVietnamese: remote.exampleVietnamese,
        imageUrl: 'http://127.0.0.1:${server.port}/pencil.jpg',
      );

      final result = await cache.cacheRelease(
        version: 'remote-1',
        words: [bundled, remoteWithUrl],
      );
      expect(result.first.localImagePath, isNull);
      expect(result.last.hasOfflineImage, isTrue);
      final file = File(result.last.localImagePath!);
      expect(await file.readAsBytes(), [0xff, 0xd8, 0xff, 0xd9]);
      expect(remoteWithUrl.imageUrl, startsWith('http://'));
    },
  );

  test(
    'media download can be cancelled before producing a cached file',
    () async {
      final root = await Directory.systemTemp.createTemp('vocab-media-cancel-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final cache = CatalogMediaCache(root: root);
      addTearDown(() async {
        cache.close();
        await server.close(force: true);
        if (await root.exists()) await root.delete(recursive: true);
      });
      server.listen((request) {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(const [0xff, 0xd8, 0xff, 0xd9]);
        unawaited(request.response.close());
      });

      final remote = CatalogWord(
        id: 'ruler',
        english: 'Ruler',
        vietnamese: 'Thước kẻ',
        topic: 'Đồ dùng học tập',
        partOfSpeech: 'noun',
        exampleEnglish: 'Use a ruler.',
        exampleVietnamese: 'Dùng thước kẻ.',
        imageUrl: 'http://127.0.0.1:${server.port}/ruler.jpg',
      );

      expect(
        () => cache.cacheRelease(
          version: 'cancelled',
          words: [remote],
          isCancelled: () => true,
        ),
        throwsA(isA<CatalogDownloadCancelled>()),
      );
    },
  );
}
