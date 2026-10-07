/// Small, deterministic review schedule used by scored recall attempts.
///
/// This is a product rule, not a claim about learning science. Flashcard
/// self-ratings and assisted answers do not advance mastery.
class ReviewState {
  final String wordId;
  final int level;
  final int recallCount;
  final DateTime? lastReviewedAt;
  final DateTime dueAt;
  final bool mastered;

  const ReviewState({
    required this.wordId,
    required this.level,
    required this.recallCount,
    required this.lastReviewedAt,
    required this.dueAt,
    required this.mastered,
  });

  Map<String, Object?> toJson() => {
    'word_id': wordId,
    'level': level,
    'recall_count': recallCount,
    'last_reviewed_at': lastReviewedAt?.toUtc().toIso8601String(),
    'due_at': dueAt.toUtc().toIso8601String(),
    'mastered': mastered ? 1 : 0,
  };

  static ReviewState fromJson(Map<String, Object?> row) => ReviewState(
    wordId: row['word_id']! as String,
    level: row['level']! as int,
    recallCount: row['recall_count']! as int,
    lastReviewedAt: row['last_reviewed_at'] == null
        ? null
        : DateTime.parse(row['last_reviewed_at']! as String).toLocal(),
    dueAt: DateTime.parse(row['due_at']! as String).toLocal(),
    mastered: row['mastered'] == 1 || row['mastered'] == true,
  );
}

class ReviewScheduler {
  static const intervals = <Duration>[
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
    Duration(days: 14),
    Duration(days: 30),
  ];

  const ReviewScheduler();

  ReviewState apply({
    required String wordId,
    required ReviewState? previous,
    required bool correct,
    bool assisted = false,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (assisted && previous != null) return previous;
    if (!correct) {
      return ReviewState(
        wordId: wordId,
        level: 1,
        recallCount: 0,
        lastReviewedAt: current,
        dueAt: current.add(intervals.first),
        mastered: false,
      );
    }

    final oldLevel = previous?.level ?? 0;
    final level = (oldLevel + 1).clamp(1, intervals.length);
    final oldLast = previous?.lastReviewedAt;
    final differentDay = oldLast == null || !_sameDay(oldLast, current);
    final recallCount = (previous?.recallCount ?? 0) + (differentDay ? 1 : 0);
    final spacedSevenDays =
        oldLast != null &&
        current.difference(oldLast) >= const Duration(days: 7);
    return ReviewState(
      wordId: wordId,
      level: level,
      recallCount: recallCount,
      lastReviewedAt: current,
      dueAt: current.add(intervals[level - 1]),
      mastered: recallCount >= 3 && level >= 3 && spacedSevenDays,
    );
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
