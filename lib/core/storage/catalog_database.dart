import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../../catalog_data.dart';

/// Storage contract for the active catalog release.
///
/// Keeping this boundary small lets state tests exercise release replacement
/// without opening a platform SQLite plugin. The production implementation is
/// [CatalogDatabase]; learner progress remains in [LocalAppStore].
abstract interface class CatalogStore {
  Future<void> replaceRelease({
    required String version,
    required List<CatalogWord> words,
  });

  Future<String?> get releaseVersion;

  Future<List<CatalogWord>> all();

  Future<void> close();
}

/// SQLite catalog boundary used by downloaded content packs.
///
/// The detector's 15 class IDs are intentionally not stored as the catalog
/// primary key. A future release can add thousands of words without changing
/// E4 or invalidating learning history.
class CatalogDatabase implements CatalogStore {
  static const _databaseName = 'vocab_catalog.db';
  static const _version = 5;

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      path.join(root, _databaseName),
      version: _version,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE catalog_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE catalog_words (
            id TEXT PRIMARY KEY,
            english TEXT NOT NULL,
            vietnamese TEXT NOT NULL,
            topic TEXT NOT NULL,
            part_of_speech TEXT NOT NULL,
            example_english TEXT NOT NULL,
            example_vietnamese TEXT NOT NULL,
            source TEXT NOT NULL,
            source_url TEXT,
            source_license TEXT,
            source_attribution TEXT,
            reviewed_by TEXT,
            reviewer_type TEXT,
            reviewer_id TEXT,
            reviewed_at TEXT,
            image_url TEXT,
            image_license TEXT,
            image_attribution TEXT,
            local_image_path TEXT,
            release_version TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX catalog_words_search ON catalog_words(english, vietnamese, topic)',
        );
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          for (final column in const [
            'source_url TEXT',
            'source_license TEXT',
            'reviewed_by TEXT',
            'image_url TEXT',
            'image_license TEXT',
            'image_attribution TEXT',
          ]) {
            await db.execute('ALTER TABLE catalog_words ADD COLUMN $column');
          }
        }
        if (oldVersion < 3) {
          for (final column in const [
            'reviewer_type TEXT',
            'reviewer_id TEXT',
            'reviewed_at TEXT',
          ]) {
            await db.execute('ALTER TABLE catalog_words ADD COLUMN $column');
          }
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE catalog_words ADD COLUMN source_attribution TEXT',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE catalog_words ADD COLUMN local_image_path TEXT',
          );
        }
      },
    );
  }

  @override
  Future<void> replaceRelease({
    required String version,
    required List<CatalogWord> words,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('catalog_words');
      final batch = txn.batch();
      for (final word in words) {
        batch.insert('catalog_words', {
          'id': word.id,
          'english': word.english,
          'vietnamese': word.vietnamese,
          'topic': word.topic,
          'part_of_speech': word.partOfSpeech,
          'example_english': word.exampleEnglish,
          'example_vietnamese': word.exampleVietnamese,
          'source': word.source,
          'source_url': word.sourceUrl,
          'source_license': word.sourceLicense,
          'source_attribution': word.sourceAttribution,
          'reviewed_by': word.reviewedBy,
          'reviewer_type': word.reviewerType,
          'reviewer_id': word.reviewerId,
          'reviewed_at': word.reviewedAt,
          'image_url': word.imageUrl,
          'image_license': word.imageLicense,
          'image_attribution': word.imageAttribution,
          'local_image_path': word.localImagePath,
          'release_version': version,
        });
      }
      await batch.commit(noResult: true);
      await txn.insert('catalog_meta', {
        'key': 'release_version',
        'value': version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('catalog_meta', {
        'key': 'word_count',
        'value': '${words.length}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<String?> get releaseVersion async {
    final db = await database;
    final rows = await db.query(
      'catalog_meta',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: const ['release_version'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<List<CatalogWord>> all() => search('');

  Future<List<CatalogWord>> search(String query, {String? topic}) async {
    final db = await database;
    final args = <Object>['%${query.trim().toLowerCase()}%'];
    var where =
        '(lower(english) LIKE ? OR lower(vietnamese) LIKE ? OR lower(topic) LIKE ?)';
    args
      ..add('%${query.trim().toLowerCase()}%')
      ..add('%${query.trim().toLowerCase()}%');
    if (topic != null && topic.isNotEmpty) {
      where += ' AND topic = ?';
      args.add(topic);
    }
    final rows = await db.query(
      'catalog_words',
      where: where,
      whereArgs: args,
      orderBy: 'english ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  CatalogWord _fromRow(Map<String, Object?> row) => CatalogWord(
    id: row['id']! as String,
    english: row['english']! as String,
    vietnamese: row['vietnamese']! as String,
    topic: row['topic']! as String,
    partOfSpeech: row['part_of_speech']! as String,
    exampleEnglish: row['example_english']! as String,
    exampleVietnamese: row['example_vietnamese']! as String,
    source: row['source']! as String,
    sourceUrl: row['source_url'] as String?,
    sourceLicense: row['source_license'] as String?,
    sourceAttribution: row['source_attribution'] as String?,
    reviewedBy: row['reviewed_by'] as String?,
    reviewerType: row['reviewer_type'] as String?,
    reviewerId: row['reviewer_id'] as String?,
    reviewedAt: row['reviewed_at'] as String?,
    imageUrl: row['image_url'] as String?,
    imageLicense: row['image_license'] as String?,
    imageAttribution: row['image_attribution'] as String?,
    localImagePath: row['local_image_path'] as String?,
  );
}
