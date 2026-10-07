import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/core/learning/review_scheduler.dart';

void main() {
  test('correct recall follows 1/3/7/14/30 day intervals', () {
    const scheduler = ReviewScheduler();
    final first = DateTime(2026, 9, 1, 9);
    final one = scheduler.apply(
      wordId: 'pencil',
      previous: null,
      correct: true,
      now: first,
    );
    expect(one.level, 1);
    expect(one.dueAt, first.add(const Duration(days: 1)));

    final two = scheduler.apply(
      wordId: 'pencil',
      previous: one,
      correct: true,
      now: first.add(const Duration(days: 1)),
    );
    expect(two.level, 2);
    expect(two.dueAt, first.add(const Duration(days: 4)));

    final three = scheduler.apply(
      wordId: 'pencil',
      previous: two,
      correct: true,
      now: first.add(const Duration(days: 8)),
    );
    expect(three.level, 3);
    expect(three.recallCount, 3);
    expect(three.mastered, isTrue);
  });

  test(
    'wrong recall resets the level and assisted answers do not advance it',
    () {
      const scheduler = ReviewScheduler();
      final now = DateTime(2026, 9, 1);
      final first = scheduler.apply(
        wordId: 'ruler',
        previous: null,
        correct: true,
        now: now,
      );
      final assisted = scheduler.apply(
        wordId: 'ruler',
        previous: first,
        correct: true,
        assisted: true,
        now: now.add(const Duration(days: 1)),
      );
      expect(assisted.level, first.level);
      expect(assisted.recallCount, first.recallCount);

      final wrong = scheduler.apply(
        wordId: 'ruler',
        previous: assisted,
        correct: false,
        now: now.add(const Duration(days: 2)),
      );
      expect(wrong.level, 1);
      expect(wrong.recallCount, 0);
      expect(wrong.mastered, isFalse);
    },
  );
}
