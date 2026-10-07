import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../catalog_data.dart';
import 'space_data.dart';

enum SpaceBulletKind { player, enemy, bounced }

class SpaceBullet {
  bool active = false;
  double x = 0, y = 0, vx = 0, vy = 0;
  SpaceBulletKind kind = SpaceBulletKind.player;
  String wordId = '';
  int color = 0;
}

class SpaceEffect {
  bool active = false;
  double x = 0, y = 0, age = 0;
}

class SpaceEnemy {
  SpaceEnemy(this.word, this.x, this.y, this.hp, this.maxHp)
    : homeX = x,
      homeY = y;
  final CatalogWord word;
  double x, y;
  final double homeX, homeY;
  double age = 0;
  int hp;
  final int maxHp;
  double angry = 0, hit = 0;
  bool alive = true;
}

class SpacePickup {
  bool active = false;
  double x = 0, y = 0;
  int index = 0;
}

class SpaceBossAttack {
  SpaceBossAttack(this.laser, this.x, this.otherX, this.y);
  final bool laser;
  final double x, otherX, y;
  double age = 0;
}

/// Fixed-step logic. Positions are normalized to the playfield, independent
/// of device pixels. Rendering is image widgets only, with no canvas artwork.
class SpaceEngine extends ChangeNotifier {
  SpaceEngine({
    required this.config,
    required this.level,
    required this.words,
    Iterable<String> priorityIds = const [],
    bool replayTutorial = false,
    math.Random? random,
    this.onSpeak,
    this.onShot,
  }) : random = random ?? math.Random(),
       tutorialActive = level.tutorial && replayTutorial {
    bullets = List.generate(
      config.p('maxBullets').toInt(),
      (_) => SpaceBullet(),
    );
    effects = List.generate(
      config.p('maxEffects').toInt(),
      (_) => SpaceEffect(),
    );
    shipY = config.p('playerY');
    final priorities = words.where((w) => priorityIds.contains(w.id)).toList();
    while (_queue.length < level.enemyCount) {
      final rest = words.where((w) => !priorities.contains(w)).toList();
      if (!level.tutorial) rest.shuffle(this.random);
      final cycle = [...priorities, ...rest];
      if (_queue.isNotEmpty &&
          cycle.first.id == _queue.last.id &&
          cycle.length > 1) {
        final first = cycle.removeAt(0);
        cycle.add(first);
      }
      _queue.addAll(cycle.take(level.enemyCount - _queue.length));
    }
    if (tutorialActive) {
      _enterStep();
    } else {
      _spawnWave();
    }
  }

  final SpaceConfig config;
  final SpaceLevel level;
  final List<CatalogWord> words;
  final math.Random random;
  final void Function(CatalogWord word)? onSpeak;
  final VoidCallback? onShot;
  final hud = ValueNotifier<int>(0);
  late final List<SpaceBullet> bullets;
  late final List<SpaceEffect> effects;
  final List<SpacePickup> pickups = List.generate(4, (_) => SpacePickup());
  SpaceBossAttack? bossAttack;
  double _spawnClock = 0, _bossClock = 0, _bossCooldown = 0;
  int _bossAttackCount = 0;
  int shotId = 0;
  int correctPickups = 0;
  int get ammoMultiplier => math.max(1, correctPickups);
  bool _bossPickups = false;
  int _modeStreak = 0;
  bool get needsPickups => level.boss ? _bossPickups : level.pickups;
  bool get listening => level.boss ? !_bossPickups : level.listening;
  double answerCooldown = 0;
  int get cooldownSeconds => answerCooldown.ceil();
  int get bossMaxHp => level.enemyCount * config.p('bossHealth').toInt();
  int get bossHp =>
      _queue.length * config.p('bossHealth').toInt() +
      enemies.where((e) => e.alive).fold<int>(0, (sum, e) => sum + e.hp);
  double get bossCharge => bossAttack == null
      ? 0
      : (bossAttack!.age /
                config.p(
                  bossAttack!.laser ? 'bossLaserCharge' : 'bossSlamCharge',
                ))
            .clamp(0, 1);
  bool get bossFiring =>
      bossAttack != null &&
      bossCharge >= 1 &&
      bossAttack!.age <
          config.p(bossAttack!.laser ? 'bossLaserCharge' : 'bossSlamCharge') +
              config.p(
                bossAttack!.laser ? 'bossLaserDuration' : 'bossSlamDuration',
              );
  final List<SpaceEnemy> enemies = [];
  final List<CatalogWord> _queue = [];
  final List<SpaceAttempt> attempts = [];
  final Map<String, CatalogWord> encountered = {};
  final Map<String, int> _repeated = {};
  final Set<String> _recordedDecisions = {};
  List<CatalogWord> choices = [];
  Set<int> collected = {};
  int selected = -1, hearts = 3, combo = 0, bestCombo = 0, defeated = 0;
  double shipX = .5, shipY = .86, invulnerable = 0;
  double elapsed = 0, backgroundOffset = 0;
  double _accumulator = 0, _shotClock = 0, _enemyClock = 0, _pickupClock = 0;
  SpacePickup? get _firstPickup {
    for (final p in pickups) {
      if (p.active) return p;
    }
    return null;
  }

  double get pickupX => _firstPickup?.x ?? .5;
  double get pickupY => _firstPickup?.y ?? 0;
  bool get pickupActive => _firstPickup != null;
  bool paused = false;
  bool tutorialActive;
  int tutorialIndex = 0;
  bool _movedLeft = false, _movedRight = false;
  String message = 'Chọn nghĩa rồi kéo phi thuyền để bắn!';
  String reaction = 'encourage';
  String? wrongAmmoId;
  int wrongFeedbackId = 0;
  String? soundEvent;
  int reactionId = 0;
  SpaceResult? result;
  SpaceEnemy? get target {
    for (final enemy in enemies) {
      if (enemy.alive) return enemy;
    }
    return null;
  }

  Map<String, dynamic>? get step =>
      tutorialActive ? config.tutorial[tutorialIndex] : null;
  bool get practice => tutorialActive;
  bool get canFire =>
      !tutorialActive ||
      ['correct', 'wrong', 'recover'].contains(step!['behavior']);
  bool get canEnemyFire =>
      !tutorialActive ||
      ['practice', 'wrong', 'recover'].contains(step!['behavior']);
  bool get canNextStep => step?['condition'] == 'tap';
  String get highlight => step?['highlight'] as String? ?? '';
  String get speech => step?['text'] as String? ?? message;
  void _ui() => hud.value++;
  void _react(String text, String expression, {String? sound}) {
    message = text;
    soundEvent = sound;
    reaction = expression;
    reactionId++;
    _ui();
  }

  void setPaused(bool value) {
    paused = value;
    _accumulator = 0;
    _ui();
  }

  void move(double x, double y) {
    if (paused || result != null) return;
    shipX = x.clamp(.08, .92);
    shipY = y.clamp(
      level.boss ? .65 : config.p('playerMinY'),
      config.p('playerMaxY'),
    );
    if (tutorialActive && step!['condition'] == 'drag_both') {
      if (shipX < .3) _movedLeft = true;
      if (shipX > .7) _movedRight = true;
      if (_movedLeft && _movedRight) _tutorialEvent('drag_both');
    }
    notifyListeners();
  }

  void select(int index) {
    if (paused || result != null || index < 0 || index >= choices.length) {
      return;
    }
    if (tutorialActive &&
        step!['behavior'] == 'choose' &&
        choices[index].id != target?.word.id) {
      wrongAmmoId = choices[index].id;
      wrongFeedbackId++;
      _react(
        'Thử lại nhé! Hãy tìm nghĩa của ${target?.word.english}.',
        'encourage',
      );
      return;
    }
    if (answerCooldown > 0) return;
    if (needsPickups && !collected.contains(index)) {
      _react(
        'Lái phi thuyền nhặt viên đạn mang nghĩa này trước nhé!',
        'thinking',
      );
      return;
    }
    if (selected == index) return;
    selected = index;
    wrongAmmoId = null;
    _shotClock = config.p('playerShotInterval');
    if (!practice && choices[index].id != target?.word.id) {
      answerCooldown = 5;
      wrongAmmoId = choices[index].id;
      wrongFeedbackId++;
      _react('Chưa đúng. Chờ 5 giây rồi chọn lại nhé!', 'memePout');
    }
    _ui();
    if (tutorialActive && choices[index].id == target?.word.id) {
      _tutorialEvent('select_correct');
    }
  }

  void nextStep() {
    if (canNextStep) _advanceStep();
  }

  void skipTutorial() {
    if (!tutorialActive) return;
    tutorialActive = false;
    enemies.clear();
    _queue.clear();
    _queue.addAll(words.take(level.enemyCount));
    _clearBullets();
    _spawnWave();
    _ui();
  }

  void _tutorialEvent(String event) {
    if (step?['condition'] == event) _advanceStep();
  }

  void _advanceStep() {
    if (tutorialIndex + 1 >= config.tutorial.length) {
      _finish(true);
      return;
    }
    tutorialIndex++;
    _enterStep();
  }

  void _enterStep() {
    _clearBullets();
    _enemyClock = 0;
    _shotClock = 0;
    final behavior = step!['behavior'];
    reaction = step!['expression'] as String;
    reactionId++;
    if ([
      'practice',
      'inspect',
      'choose',
      'correct',
      'wrong',
      'recover',
    ].contains(behavior)) {
      final word = words[(step!['wordIndex'] as int) % words.length];
      if (target?.word.id != word.id) {
        enemies.clear();
        enemies.add(SpaceEnemy(word, .5, config.p('enemyY'), 1, 1));
        _prepareTarget();
      }
      if (behavior == 'wrong') selected = -1;
      if (behavior == 'inspect') onSpeak?.call(word);
    } else {
      enemies.clear();
      selected = -1;
    }
    _ui();
  }

  void _spawnWave() {
    final previousBoss = level.boss && enemies.isNotEmpty ? enemies.last : null;
    enemies.removeWhere((e) => !e.alive);
    if (_queue.isEmpty) {
      if (target == null) _finish(true);
      return;
    }
    final hadTarget = target != null;
    if (enemies.length >= level.simultaneous) return;
    final word = _queue.removeAt(0);
    final health = config.p(level.boss ? 'bossHealth' : 'enemyHealth').toInt();
    final lanes = level.simultaneous == 2 ? [.28, .72] : [.25, .5, .75];
    final x = level.boss || level.simultaneous == 1
        ? .5
        : lanes.firstWhere(
            (lane) => enemies.every((e) => (e.homeX - lane).abs() > .05),
          );
    final enemy = SpaceEnemy(
      word,
      x,
      (level.json['enemyY'] as num?)?.toDouble() ?? config.p('enemyY'),
      health,
      health,
    );
    enemy.y = -.14;
    if (previousBoss != null && defeated > 0) {
      enemy.age = previousBoss.age;
      enemy.x = previousBoss.x;
      enemy.y = previousBoss.y;
    }
    enemies.add(enemy);
    if (!hadTarget) _prepareTarget();
  }

  void _prepareTarget() {
    final enemy = target;
    if (enemy == null) return;
    // Old auto-fired ammo must not be scored as a wrong answer against a new
    // word after the target switches. Enemy bullets remain avoidable in flight.
    for (final bullet in bullets) {
      if (bullet.kind != SpaceBulletKind.enemy) bullet.active = false;
    }
    encountered[enemy.word.id] = enemy.word;
    final distractors =
        words.where((w) => w.vietnamese != enemy.word.vietnamese).toList()
          ..shuffle(random);
    final seen = <String>{enemy.word.vietnamese};
    choices = [enemy.word];
    for (final w in distractors) {
      if (seen.add(w.vietnamese)) choices.add(w);
      if (choices.length == level.choices) break;
    }
    choices.shuffle(random);
    selected = -1;
    wrongAmmoId = null;
    if (level.boss) {
      final next = _modeStreak >= 2 ? !_bossPickups : random.nextBool();
      _modeStreak = next == _bossPickups ? _modeStreak + 1 : 1;
      _bossPickups = next;
      message = needsPickups
          ? 'Đổi chế độ: né và nhặt đạn đúng nghĩa!'
          : 'Đổi chế độ: nghe từ rồi chọn nghĩa để bắn!';
    }
    answerCooldown = 0;
    collected = needsPickups
        ? {}
        : {for (var i = 0; i < choices.length; i++) i};
    _recordedDecisions.clear();
    _enemyClock = 0;
    for (final pickup in pickups) {
      pickup.active = false;
    }
    _pickupClock = 0;
    if (listening) onSpeak?.call(enemy.word);
    _ui();
  }

  void update(double delta) {
    if (paused || result != null || !delta.isFinite || delta <= 0) return;
    final fixed = config.p('fixedStep');
    _accumulator = math.min(
      _accumulator + delta,
      fixed * config.p('maxCatchUpSteps'),
    );
    var changed = false;
    while (_accumulator >= fixed) {
      _accumulator -= fixed;
      _tick(fixed);
      changed = true;
      if (result != null) break;
    }
    if (changed) notifyListeners();
  }

  void _tick(double dt) {
    elapsed += dt;
    if (answerCooldown > 0) {
      final previous = cooldownSeconds;
      answerCooldown = math.max(0, answerCooldown - dt);
      if (cooldownSeconds != previous) _ui();
    }
    backgroundOffset =
        (backgroundOffset + config.p('backgroundSpeed') * dt) % 1;
    invulnerable = math.max(0, invulnerable - dt);
    _bossCooldown = math.max(0, _bossCooldown - dt);
    if (!tutorialActive && !level.boss) {
      _spawnClock += dt;
      if (_spawnClock >= config.p('enemySpawnInterval')) {
        _spawnClock = 0;
        _spawnWave();
      }
    }
    for (final e in enemies) {
      e.age += dt;
      e.angry = math.max(0, e.angry - dt);
      e.hit = math.max(0, e.hit - dt);
      if (!tutorialActive) {
        final entrance = (e.age / config.p('enemyEntrance')).clamp(0.0, 1.0);
        final ease = 1 - math.pow(1 - entrance, 3);
        e.x =
            (e.homeX +
                    math.sin(e.age * config.p('enemyMoveSpeed') + e.homeX * 4) *
                        config.p(
                          level.boss
                              ? 'bossMoveAmplitude'
                              : 'enemyMoveAmplitude',
                        ))
                .clamp(.12, .88);
        e.y =
            -.14 +
            (e.homeY + .14) * ease +
            math.sin(e.age * 1.8) * config.p('enemyBobAmplitude') * entrance;
      }
    }
    final active = target;
    _shotClock += dt;
    if (active != null &&
        selected >= 0 &&
        canFire &&
        _shotClock >= config.p('playerShotInterval')) {
      _shotClock = 0;
      shotId++;
      onShot?.call();
      final count = math.min(
        choices[selected].id == active.word.id ? ammoMultiplier : 1,
        bullets.length,
      );
      for (var i = 0; i < count; i++) {
        _launch(
          (shipX + (i - (count - 1) / 2) * .014).clamp(.02, .98),
          shipY - .05,
          0,
          -config.p('playerBulletSpeed'),
          SpaceBulletKind.player,
          choices[selected].id,
          selected % 3,
        );
      }
    }
    _enemyClock += dt;
    if (active != null &&
        canEnemyFire &&
        (tutorialActive || active.age >= config.p('enemyEntrance'))) {
      final angry = active.angry > 0;
      final interval =
          level.interval * (angry ? config.p('angerRateMultiplier') : 1);
      if (_enemyClock >= interval) {
        _enemyClock = 0;
        final speed =
            level.speed * (angry ? config.p('angerSpeedMultiplier') : 1);
        final fan =
            level.json['pattern'] == 'fan' &&
            (!level.boss || elapsed.floor().isEven);
        final aim = tutorialActive
            ? math.pi / 2
            : math.atan2(shipY - active.y - .05, shipX - active.x);
        for (final spread in fan ? [-.16, 0.0, .16] : [0.0]) {
          _launch(
            active.x,
            active.y + .05,
            math.cos(aim + spread) * speed,
            math.sin(aim + spread) * speed,
            SpaceBulletKind.enemy,
            '',
            0,
          );
        }
      }
    }

    for (final bullet in bullets) {
      if (!bullet.active) continue;
      bullet.x += bullet.vx * dt;
      bullet.y += bullet.vy * dt;
      if (bullet.y < -.06 ||
          bullet.y > 1.06 ||
          bullet.x < -.06 ||
          bullet.x > 1.06) {
        final dodged = bullet.kind == SpaceBulletKind.enemy;
        bullet.active = false;
        if (dodged) _tutorialEvent('dodge_wave');
        continue;
      }
      if (bullet.kind == SpaceBulletKind.player) {
        final enemy = target;
        if (enemy != null &&
            (bullet.x - enemy.x).abs() <
                config.p(level.boss ? 'bossRadiusX' : 'enemyRadius') +
                    config.p('playerBulletRadius') &&
            (bullet.y - enemy.y).abs() <
                config.p(level.boss ? 'bossRadiusY' : 'enemyRadius')) {
          resolveHit(bullet, enemy);
        }
      } else if (bullet.kind == SpaceBulletKind.enemy &&
          (bullet.x - shipX).abs() <
              config.p('shipRadius') + config.p('enemyBulletRadius') &&
          (bullet.y - shipY).abs() < config.p('shipRadius')) {
        bullet.active = false;
        hurt();
      }
      if (result != null) break;
    }
    for (final effect in effects) {
      if (!effect.active) continue;
      effect.age += dt;
      if (effect.age >= config.p('effectDuration')) effect.active = false;
    }
    if (level.boss && !tutorialActive && active != null) _tickBoss(dt);
    if (needsPickups && target != null) {
      _pickupClock += dt;
      if (!pickupActive && _pickupClock >= config.p('pickupInterval')) {
        _pickupClock = 0;
        for (var i = 0; i < choices.length; i++) {
          final p = pickups[i];
          p.active = true;
          p.index = i;
          p.x = .14 + i * .72 / math.max(1, choices.length - 1);
          // Enter from above the playfield, never from the boss body.
          p.y = -.08 - i * .06;
        }
      }
      for (final p in pickups) {
        if (!p.active) continue;
        p.y += dt * config.p('pickupSpeed');
        if (answerCooldown <= 0 &&
            (p.x - shipX).abs() < config.p('pickupRadius') &&
            (p.y - shipY).abs() < config.p('pickupRadius')) {
          collected.add(p.index);
          if (choices[p.index].id == target?.word.id) correctPickups++;
          p.active = false;
          select(p.index);
          _react(
            choices[p.index].id == target?.word.id
                ? 'Nhặt đúng! Hỏa lực ×$ammoMultiplier. Lái để bắn nhé.'
                : 'Bé vừa nhặt nghĩa khác. Né và tìm nghĩa đúng nhé!',
            'thinking',
            sound: 'pickup',
          );
          _ui();
        } else if (p.y > 1.06) {
          p.active = false;
        }
      }
    }
  }

  void _startBossAttack({bool punish = false}) {
    if (bossAttack != null || _bossCooldown > 0 || target == null) return;
    final laser = punish || _bossAttackCount.isOdd;
    _bossAttackCount++;
    final x = shipX.clamp(.14, .86);
    bossAttack = SpaceBossAttack(
      laser,
      x,
      (x > .5 ? x - .27 : x + .27).clamp(.12, .88),
      shipY,
    );
    _react(
      laser
          ? 'Boss đang tích năng lượng! Né khỏi hai vệt sáng!'
          : 'Xúc tu sắp quật! Lái sang bên nhé!',
      'memeSurprised',
    );
  }

  void _tickBoss(double dt) {
    _bossClock += dt;
    if (bossAttack == null &&
        _bossClock >=
            config.p('bossAttackInterval') *
                (bossHp < bossMaxHp / 2 ? .78 : 1)) {
      _bossClock = 0;
      _startBossAttack();
    }
    final attack = bossAttack;
    if (attack == null) return;
    final wasFiring = bossFiring;
    attack.age += dt;
    if (!wasFiring && bossFiring) {
      _react('Né ngay! Bé làm được!', 'memeSurprised', sound: 'laser');
    }
    if (bossFiring) {
      final inLaser =
          attack.laser &&
          shipY >= .55 &&
          ((shipX - attack.x).abs() <
                  config.p('bossLaserHalfWidth') + config.p('shipRadius') ||
              (shipX - attack.otherX).abs() <
                  config.p('bossLaserHalfWidth') + config.p('shipRadius'));
      final inSlam =
          !attack.laser &&
          ((shipX - attack.x).abs() < config.p('bossSlamRadius') ||
              (shipX - attack.otherX).abs() < config.p('bossSlamRadius')) &&
          (shipY - attack.y).abs() < config.p('bossSlamRadius');
      if (inLaser || inSlam) hurt();
    }
    if (attack.age >=
        config.p(attack.laser ? 'bossLaserCharge' : 'bossSlamCharge') +
            config.p(attack.laser ? 'bossLaserDuration' : 'bossSlamDuration')) {
      bossAttack = null;
      _bossCooldown = config.p('bossRecovery');
    }
  }

  void _launch(
    double x,
    double y,
    double vx,
    double vy,
    SpaceBulletKind kind,
    String word,
    int color,
  ) {
    for (final b in bullets) {
      if (!b.active) {
        b.active = true;
        b.x = x;
        b.y = y;
        b.vx = vx;
        b.vy = vy;
        b.kind = kind;
        b.wordId = word;
        b.color = color;
        return;
      }
    }
  }

  void _clearBullets() {
    for (final b in bullets) {
      b.active = false;
    }
  }

  @visibleForTesting
  void resolveHit(SpaceBullet bullet, SpaceEnemy enemy) {
    if (!enemy.alive || result != null) return;
    final correct = bullet.wordId == enemy.word.id;
    final key = '${enemy.word.id}:${bullet.wordId}';
    if (_recordedDecisions.add(key)) {
      attempts.add(SpaceAttempt(enemy.word, correct, assisted: practice));
    }
    enemy.hit = .18;
    if (!correct) {
      bullet.kind = SpaceBulletKind.bounced;
      bullet.vy = config.p('playerBulletSpeed') * .4;
      bullet.vx = .16;
      enemy.angry = level.anger;
      combo = 0;
      wrongAmmoId = bullet.wordId;
      wrongFeedbackId++;
      _react(
        'Đạn bật ra rồi! Hãy chọn lại nghĩa của ${enemy.word.english}.',
        'memePout',
        sound: 'wrong',
      );
      if (level.boss && !practice) _startBossAttack(punish: true);
      if (!practice &&
          !level.boss &&
          (_repeated[enemy.word.id] ?? 0) < config.p('wrongRepeatLimit')) {
        _queue.add(enemy.word);
        _repeated.update(enemy.word.id, (v) => v + 1, ifAbsent: () => 1);
      }
      _tutorialEvent('wrong_hit');
      return;
    }
    bullet.active = false;
    wrongAmmoId = null;
    enemy.hp--;
    _ui();
    if (enemy.hp > 0) return;
    enemy.alive = false;
    defeated++;
    combo++;
    bestCombo = math.max(bestCombo, combo);
    onSpeak?.call(enemy.word);
    for (final e in effects) {
      if (!e.active) {
        e.active = true;
        e.x = enemy.x;
        e.y = enemy.y;
        e.age = 0;
        break;
      }
    }
    final milestones =
        (config.json['physics'] as Map)['comboMilestones'] as List;
    _react(
      milestones.contains(combo)
          ? 'Combo $combo! Bé nhớ từ giỏi quá!'
          : 'Đúng rồi: ${enemy.word.english} — ${enemy.word.vietnamese}!',
      combo.isEven ? 'memeLaugh' : 'memeSurprised',
      sound: 'correct',
    );
    if (tutorialActive) {
      _tutorialEvent('defeat_target');
    } else if (target == null) {
      _spawnWave();
    } else {
      _prepareTarget();
    }
  }

  @visibleForTesting
  void hurt() {
    if (invulnerable > 0 || result != null) return;
    invulnerable = config.p('invulnerability');
    if (practice) return;
    hearts--;
    _react(
      hearts == 1
          ? 'Còn một tim. Bình tĩnh, bé làm được!'
          : 'Né sang bên nhé! Mây luôn ở đây.',
      'memePout',
      sound: 'hit',
    );
    if (hearts <= 0) _finish(false);
    _ui();
  }

  int starsFor(bool won) {
    if (!won) return 0;
    if (practice) return 1;
    final scored = attempts.where((a) => !a.assisted).toList();
    final accuracy = scored.isEmpty
        ? 0.0
        : scored.where((a) => a.correct).length / scored.length;
    final rules = config.json['stars'] as Map;
    if (hearts >= (rules['threeHearts'] as num) &&
        accuracy >= (rules['threeAccuracy'] as num)) {
      return 3;
    }
    if (hearts >= (rules['twoHearts'] as num) &&
        accuracy >= (rules['twoAccuracy'] as num)) {
      return 2;
    }
    return 1;
  }

  void _finish(bool won) {
    if (result != null) return;
    result = SpaceResult(
      won: won,
      hearts: hearts,
      stars: starsFor(won),
      attempts: List.unmodifiable(attempts),
      words: List.unmodifiable(encountered.values),
    );
    paused = true;
    _ui();
  }

  @override
  void dispose() {
    hud.dispose();
    super.dispose();
  }
}
