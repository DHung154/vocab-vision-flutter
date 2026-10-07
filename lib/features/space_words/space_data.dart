import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../../catalog_data.dart';

const spaceAssets = 'assets/games/space_words/';

class SpaceConfig {
  SpaceConfig(this.json) {
    final rects = json['spriteRects'] as Map;
    for (final name in spriteNames) {
      final rect = (rects[name] as List).cast<num>();
      if (rect.length != 4 ||
          rect[0] < 0 ||
          rect[1] < 0 ||
          rect[2] <= 0 ||
          rect[3] <= 0 ||
          rect[0] + rect[2] > 1 ||
          rect[1] + rect[3] > 1) {
        throw FormatException('Tọa độ sprite "$name" không hợp lệ.');
      }
    }
    levels = (json['levels'] as List)
        .map((v) => SpaceLevel(Map<String, dynamic>.from(v as Map)))
        .toList();
    if (levels.isEmpty ||
        levels.first.id != 1 ||
        levels.map((e) => e.id).toSet().length != levels.length) {
      throw const FormatException('Cấu hình màn chơi không hợp lệ.');
    }
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      if (level.id != i + 1 ||
          level.choices < 2 ||
          level.choices > 4 ||
          level.enemyCount < 1 ||
          level.simultaneous < 1 ||
          level.simultaneous > 3 ||
          level.speed <= 0 ||
          level.interval <= 0 ||
          level.wordIds.isEmpty) {
        throw FormatException('Cấu hình màn ${level.id} không hợp lệ.');
      }
    }
    if (p('fixedStep') <= 0 ||
        p('maxCatchUpSteps') < 1 ||
        p('maxBullets') < 1 ||
        p('maxEffects') < 1 ||
        p('playerShotInterval') <= 0 ||
        p('invulnerability') <= 0) {
      throw const FormatException('Thông số vật lý không hợp lệ.');
    }
    for (final key in [
      'enemyEntrance',
      'enemySpawnInterval',
      'bossHealth',
      'bossLaserCharge',
      'bossLaserDuration',
      'bossSlamCharge',
      'bossSlamDuration',
      'bossRecovery',
    ]) {
      if (!p(key).isFinite || p(key) <= 0) {
        throw FormatException('Thông số "$key" phải là số dương hữu hạn.');
      }
    }
  }
  final Map<String, dynamic> json;
  late final List<SpaceLevel> levels;
  double p(String key) => ((json['physics'] as Map)[key] as num).toDouble();
  String? musicFor(bool boss, math.Random random) {
    final audio = json['audio'] as Map;
    if (!boss) return audio['music'] as String?;
    final rare = audio['rareBossMusic'] as String?;
    return rare != null && rare.isNotEmpty && random.nextInt(3) == 0
        ? rare
        : audio['bossMusic'] as String?;
  }

  List<Map<String, dynamic>> get tutorial => (json['tutorial'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  List<String> get spriteNames => (json['spriteNames'] as List).cast<String>();
  Map<String, dynamic> get overrides =>
      Map<String, dynamic>.from(json['spriteOverrides'] as Map);
  static Future<SpaceConfig> load() async => SpaceConfig(
    Map<String, dynamic>.from(
      jsonDecode(await rootBundle.loadString('${spaceAssets}game_config.json'))
          as Map,
    ),
  );

  List<CatalogWord> wordsFor(SpaceLevel level, List<CatalogWord> catalog) {
    final byId = {for (final word in catalog) word.id: word};
    final words = <CatalogWord>[];
    for (final id in level.wordIds) {
      final word = byId[id];
      if (word == null ||
          word.english.trim().isEmpty ||
          word.vietnamese.trim().isEmpty ||
          !level.allowedTopics.contains(word.topic)) {
        throw FormatException(
          'Màn ${level.id}: thiếu từ "$id" đúng chủ đề "${level.topic}" trong catalog.',
        );
      }
      words.add(word);
    }
    if (words.map((w) => w.vietnamese).toSet().length < level.choices) {
      throw FormatException(
        'Màn ${level.id}: chưa đủ nghĩa khác nhau để chọn đạn.',
      );
    }
    return words;
  }
}

class SpaceLevel {
  SpaceLevel(this.json);
  final Map<String, dynamic> json;
  int get id => json['id'] as int;
  String get title => json['title'] as String;
  String get topic => json['topic'] as String;
  List<String> get allowedTopics =>
      (json['allowedTopics'] as List?)?.cast<String>() ?? [topic];
  List<String> get wordIds => (json['wordIds'] as List).cast<String>();
  int get enemyCount => json['enemyCount'] as int;
  int get simultaneous => json['simultaneous'] as int;
  int get choices => json['choices'] as int;
  double get speed => (json['enemySpeed'] as num).toDouble();
  double get interval => (json['enemyInterval'] as num).toDouble();
  double get anger => (json['angerSeconds'] as num).toDouble();
  bool get listening => json['listening'] == true;
  bool get pickups => json['pickups'] == true;
  bool get tutorial => json['tutorial'] == true;
  bool get boss => json['boss'] == true;
  String get background => json['background'] as String;
  double get mapX => (json['mapX'] as num).toDouble();
  double get mapY => (json['mapY'] as num).toDouble();
}

class SpaceProgress {
  SpaceProgress({
    Map<int, int>? stars,
    Map<String, int>? mistakes,
    this.tutorialDone = false,
    this.ship = 'ship_mint',
    this.sound = true,
    this.music = true,
  }) : stars = stars ?? {},
       mistakes = mistakes ?? {};
  final Map<int, int> stars;
  final Map<String, int> mistakes;
  bool tutorialDone;
  String ship;
  bool sound;
  bool music;
  int get totalStars => stars.values.fold(0, (a, b) => a + b);
  int get unlocked {
    var next = 1;
    while ((stars[next] ?? 0) > 0) {
      next++;
    }
    return next;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'stars': {for (final e in stars.entries) '${e.key}': e.value},
    'mistakes': mistakes,
    'tutorialDone': tutorialDone,
    'ship': ship,
    'sound': sound,
    'music': music,
  };
  factory SpaceProgress.fromJson(Map<String, dynamic> json) {
    final stars = <int, int>{};
    final mistakes = <String, int>{};
    final rawStars = json['stars'];
    if (rawStars is Map) {
      for (final e in rawStars.entries) {
        final id = int.tryParse(e.key.toString());
        if (id != null && id > 0 && e.value is num) {
          stars[id] = (e.value as num).toInt().clamp(0, 3);
        }
      }
    }
    final rawMistakes = json['mistakes'];
    if (rawMistakes is Map) {
      for (final e in rawMistakes.entries) {
        if (e.key is String && e.value is num && (e.value as num) > 0) {
          mistakes[e.key as String] = (e.value as num).toInt().clamp(0, 10000);
        }
      }
    }
    return SpaceProgress(
      stars: stars,
      mistakes: mistakes,
      tutorialDone: json['tutorialDone'] == true,
      ship: json['ship'] is String ? json['ship'] as String : 'ship_mint',
      sound: json['sound'] != false,
      music: json['music'] != false,
    );
  }
  void record(int levelId, SpaceResult result) {
    if (result.won) {
      stars[levelId] = math.max(stars[levelId] ?? 0, result.stars);
      if (levelId == 1) tutorialDone = true;
    }
    for (final attempt in result.attempts) {
      if (!attempt.correct && !attempt.assisted) {
        mistakes.update(attempt.word.id, (v) => v + 1, ifAbsent: () => 1);
      }
    }
  }
}

class SpaceAttempt {
  const SpaceAttempt(this.word, this.correct, {this.assisted = false});
  final CatalogWord word;
  final bool correct;
  final bool assisted;
}

class SpaceResult {
  const SpaceResult({
    required this.won,
    required this.hearts,
    required this.stars,
    required this.attempts,
    required this.words,
  });
  final bool won;
  final int hearts;
  final int stars;
  final List<SpaceAttempt> attempts;
  final List<CatalogWord> words;
  double get accuracy {
    final scored = attempts.where((a) => !a.assisted).toList();
    return scored.isEmpty
        ? 0
        : scored.where((a) => a.correct).length / scored.length;
  }
}
