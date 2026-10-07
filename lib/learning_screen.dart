import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'mascot/may_mascot.dart';
import 'mascot/may_feedback.dart';
import 'vocabulary_data.dart';

/// Supported practice modes.  Each mode has a different interaction contract;
/// keep this enum as the single source of truth for draft restoration and the
/// home-mode picker.
enum LearningMode {
  flashcard,
  matching,
  fillWord,
  listening,
  translation,
  imageWriting,
}

typedef LearningAttemptCallback =
    Future<void> Function(String wordId, bool correct, bool assisted);

typedef DetailedLearningAttemptCallback =
    Future<void> Function(
      String wordId,
      bool correct,
      bool assisted, {
      required String questionType,
      required String sessionId,
    });

class LearningSessionSummary {
  final int correct;
  final int total;
  final Set<String> wordLabels;

  const LearningSessionSummary({
    required this.correct,
    required this.total,
    required this.wordLabels,
  });
}

extension LearningModeInfo on LearningMode {
  String get title => switch (this) {
    LearningMode.flashcard => 'Flashcard',
    LearningMode.matching => 'Ghép cặp',
    LearningMode.fillWord => 'Điền từ',
    LearningMode.listening => 'Nghe & chọn',
    LearningMode.translation => 'Dịch từ',
    LearningMode.imageWriting => 'Nhìn hình viết từ',
  };

  IconData get icon => switch (this) {
    LearningMode.flashcard => Icons.style_outlined,
    LearningMode.matching => Icons.compare_arrows_outlined,
    LearningMode.fillWord => Icons.edit_outlined,
    LearningMode.listening => Icons.hearing_outlined,
    LearningMode.translation => Icons.translate_outlined,
    LearningMode.imageWriting => Icons.image_search_outlined,
  };
}

class LearningScreen extends StatefulWidget {
  final LearningMode mode;
  final List<VocabularyWord> words;
  final ValueChanged<LearningSessionSummary>? onCompleted;
  final int direction;
  final int difficulty;
  final Map<String, dynamic>? Function()? loadDraft;
  final Future<void> Function(Map<String, dynamic> draft)? saveDraft;
  final Future<void> Function()? clearDraft;
  final LearningAttemptCallback? onAttempt;
  final DetailedLearningAttemptCallback? onDetailedAttempt;
  final String? sessionId;

  const LearningScreen({
    super.key,
    required this.mode,
    this.words = vocabularyWords,
    this.onCompleted,
    this.direction = 0,
    this.difficulty = 1,
    this.loadDraft,
    this.saveDraft,
    this.clearDraft,
    this.onAttempt,
    this.onDetailedAttempt,
    this.sessionId,
  });

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen>
    with WidgetsBindingObserver {
  static const _ttsChannel = MethodChannel('vocab_vision/tts');

  final _answerController = TextEditingController();

  int _index = 0;
  int _correct = 0;
  bool _answered = false;
  bool _revealed = false;
  bool _finished = false;
  bool _saved = false;
  bool _exitDialogOpen = false;
  Future<void> _draftWrite = Future<void>.value();
  Future<void> _attemptWrite = Future<void>.value();
  VocabularyWord? _selected;
  final Set<String> _masteredThisSession = <String>{};
  final Set<String> _matchingMatched = <String>{};
  VocabularyWord? _matchingLeft;
  VocabularyWord? _matchingRight;
  bool _matchingWrong = false;
  // Choice answers are generated once per question. Keeping them out of the
  // build path prevents a setState (for example after selecting an answer)
  // from changing the visual order under the learner's finger.
  final Map<int, List<VocabularyWord>> _choiceOptionsByIndex =
      <int, List<VocabularyWord>>{};
  late String _sessionId;

  VocabularyWord get _word => _words[_index];

  List<VocabularyWord> get _words => widget.words;

  bool get _vietnameseToEnglish => widget.direction == 0;

  String _promptFor(VocabularyWord word) =>
      _vietnameseToEnglish ? word.vietnamese : word.english;

  String _answerFor(VocabularyWord word) =>
      _vietnameseToEnglish ? word.english : word.vietnamese;

  String get _wordsSignature => _words.map((word) => word.apiLabel).join('|');

  int get _optionCount => widget.difficulty == 0 ? 2 : 4;

  bool get _isChoiceMode =>
      widget.mode == LearningMode.listening ||
      widget.mode == LearningMode.translation;

  @override
  void initState() {
    super.initState();
    assert(
      widget.words.isNotEmpty,
      'LearningScreen requires at least one word',
    );
    WidgetsBinding.instance.addObserver(this);
    _sessionId =
        widget.sessionId ?? 'session-${DateTime.now().microsecondsSinceEpoch}';
    _restoreDraft();
  }

  List<VocabularyWord> get _matchingBatch =>
      _words.skip(_index).take(4).toList();

  List<VocabularyWord> get _matchingRightOptions {
    final batch = _matchingBatch;
    if (batch.isEmpty) return const [];
    // Rotate the right column by a deterministic offset so the first batch is
    // not already aligned while keeping the session reproducible.
    final shift = (_index ~/ batch.length + 1) % batch.length;
    return [...batch.skip(shift), ...batch.take(shift)];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _answerController.dispose();
    unawaited(_ttsChannel.invokeMethod<void>('stop'));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_persistDraft());
    }
  }

  void _restoreDraft() {
    final draft = widget.loadDraft?.call();
    if (draft == null ||
        draft['mode'] != widget.mode.name ||
        draft['direction'] != widget.direction ||
        draft['difficulty'] != widget.difficulty ||
        (draft['words'] is String && draft['words'] != _wordsSignature)) {
      return;
    }
    final index = draft['index'];
    if (index is! int || index < 0 || index >= _words.length) {
      return;
    }
    VocabularyWord? findWord(Object? label) {
      if (label is! String) return null;
      for (final word in _words) {
        if (word.apiLabel == label) return word;
      }
      return null;
    }

    final mastered = draft['mastered'] is List
        ? (draft['mastered'] as List).whereType<String>().toSet()
        : <String>{};
    final matched = draft['matchingMatched'] is List
        ? (draft['matchingMatched'] as List).whereType<String>().toSet()
        : <String>{};
    final correct = draft['correct'];
    final answered = draft['answered'];
    final revealed = draft['revealed'];
    setState(() {
      _index = index;
      _correct = correct is int ? correct.clamp(0, _words.length).toInt() : 0;
      _answered = answered == true;
      _revealed = revealed == true;
      _selected = findWord(draft['selected']);
      _masteredThisSession
        ..clear()
        ..addAll(mastered);
      _matchingMatched
        ..clear()
        ..addAll(matched);
      _matchingLeft = findWord(draft['matchingLeft']);
      _matchingRight = findWord(draft['matchingRight']);
      _matchingWrong = false;
      final answer = draft['answer'];
      _answerController.text = answer is String ? answer : '';
    });
    final savedSession = draft['sessionId'];
    if (savedSession is String && savedSession.trim().isNotEmpty) {
      _sessionId = savedSession;
    }
  }

  @override
  void didUpdateWidget(covariant LearningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.direction != widget.direction ||
        oldWidget.difficulty != widget.difficulty ||
        oldWidget.words != widget.words) {
      _choiceOptionsByIndex.clear();
    }
  }

  Map<String, dynamic> _draftPayload() => {
    'version': 1,
    'sessionId': _sessionId,
    'mode': widget.mode.name,
    'direction': widget.direction,
    'difficulty': widget.difficulty,
    'words': _wordsSignature,
    'index': _index,
    'correct': _correct,
    'answered': _answered,
    'revealed': _revealed,
    'selected': _selected?.apiLabel,
    'mastered': _masteredThisSession.toList()..sort(),
    'matchingMatched': _matchingMatched.toList()..sort(),
    'matchingLeft': _matchingLeft?.apiLabel,
    'matchingRight': _matchingRight?.apiLabel,
    'answer': _answerController.text,
  };

  Future<void> _persistDraft() {
    final save = widget.saveDraft;
    if (save == null || _finished) return _draftWrite;
    _draftWrite = _draftWrite.then((_) => save(_draftPayload()));
    return _draftWrite;
  }

  Future<void> _clearSavedDraft() {
    final clear = widget.clearDraft;
    if (clear == null) return _draftWrite;
    _draftWrite = _draftWrite.then((_) => clear());
    return _draftWrite;
  }

  Future<void> _recordAttempt({
    required String wordId,
    required bool correct,
    bool assisted = false,
  }) {
    final callback = widget.onAttempt;
    final detailed = widget.onDetailedAttempt;
    // Keep attempts in answer order. This matters for matching (several
    // pairs can be resolved quickly) and prevents a route pop from racing the
    // transaction that writes the final answer to SQLite/outbox.
    _attemptWrite = _attemptWrite.then((_) async {
      if (detailed != null) {
        await detailed(
          wordId,
          correct,
          assisted,
          questionType: widget.mode.name,
          sessionId: _sessionId,
        );
      }
      if (callback != null) await callback(wordId, correct, assisted);
    });
    return _attemptWrite;
  }

  List<VocabularyWord> _options() {
    final cached = _choiceOptionsByIndex[_index];
    if (cached != null) return cached;

    // Choose distractors first, then always include the correct answer. The
    // old rotate-then-take implementation could remove the answer on easy
    // mode, creating an impossible question.
    final distractors = <VocabularyWord>[];
    for (
      var offset = 3;
      distractors.length < 3 && offset < _words.length + 3;
      offset += 4
    ) {
      final candidate = _words[(_index + offset) % _words.length];
      if (candidate.apiLabel != _word.apiLabel &&
          !distractors.any((item) => item.apiLabel == candidate.apiLabel)) {
        distractors.add(candidate);
      }
    }
    final selected = <VocabularyWord>[
      _word,
      ...distractors,
    ].take(_optionCount).toList();
    selected.shuffle();
    final stableOptions = List<VocabularyWord>.unmodifiable(selected);
    _choiceOptionsByIndex[_index] = stableOptions;
    return stableOptions;
  }

  void _select(VocabularyWord selected) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    final correct = selected.apiLabel == _word.apiLabel;
    setState(() {
      _selected = selected;
      _answered = true;
      if (correct) {
        _correct++;
        _masteredThisSession.add(_word.apiLabel);
      }
    });
    unawaited(_recordAttempt(wordId: _word.apiLabel, correct: correct));
    unawaited(_persistDraft());
  }

  void _checkFillWord() {
    if (_answered || _answerController.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    final answer = _answerController.text.trim().toLowerCase();
    final expected = widget.mode == LearningMode.imageWriting
        ? _word.english
        : _answerFor(_word);
    final correct = answer == expected.toLowerCase();
    setState(() {
      _answered = true;
      if (correct) {
        _correct++;
        _masteredThisSession.add(_word.apiLabel);
      }
    });
    unawaited(_recordAttempt(wordId: _word.apiLabel, correct: correct));
    unawaited(_persistDraft());
  }

  void _recordFlashcard(bool remembered) {
    HapticFeedback.lightImpact();
    // Self-rating is useful feedback for the learner, but is not an objective
    // recall score and therefore must not create a review-scheduler attempt.
    // A remembered card is still a practiced word for daily progress.
    if (remembered) {
      _correct++;
      _masteredThisSession.add(_word.apiLabel);
    }
    _next();
  }

  void _selectMatchingLeft(VocabularyWord word) {
    if (_matchingMatched.contains(word.apiLabel)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _matchingLeft = word;
      _matchingWrong = false;
    });
    _resolveMatchingPair();
    unawaited(_persistDraft());
  }

  void _selectMatchingRight(VocabularyWord word) {
    if (_matchingMatched.contains(word.apiLabel)) return;
    HapticFeedback.lightImpact();
    setState(() {
      _matchingRight = word;
      _matchingWrong = false;
    });
    _resolveMatchingPair();
    unawaited(_persistDraft());
  }

  void _resolveMatchingPair() {
    final left = _matchingLeft;
    final right = _matchingRight;
    if (left == null || right == null) return;
    if (left.apiLabel == right.apiLabel) {
      setState(() {
        _matchingMatched.add(left.apiLabel);
        _matchingLeft = null;
        _matchingRight = null;
        _correct++;
        _masteredThisSession.add(left.apiLabel);
        if (_matchingMatched.length == _matchingBatch.length) {
          _answered = true;
        }
      });
      unawaited(_recordAttempt(wordId: left.apiLabel, correct: true));
      unawaited(_persistDraft());
      return;
    }
    setState(() => _matchingWrong = true);
    unawaited(_recordAttempt(wordId: left.apiLabel, correct: false));
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || !_matchingWrong) return;
      setState(() {
        _matchingLeft = null;
        _matchingRight = null;
        _matchingWrong = false;
      });
    });
  }

  void _nextMatchingBatch() {
    final nextIndex = _index + _matchingBatch.length;
    if (nextIndex >= _words.length) {
      _finishSession();
      return;
    }
    setState(() {
      _index = nextIndex;
      _answered = false;
      _matchingMatched.clear();
      _matchingLeft = null;
      _matchingRight = null;
      _matchingWrong = false;
    });
    unawaited(_persistDraft());
  }

  void _finishSession() {
    if (!_saved) {
      _saved = true;
      unawaited(_clearSavedDraft());
      final summary = LearningSessionSummary(
        correct: widget.mode == LearningMode.flashcard ? 0 : _correct,
        total: _words.length,
        wordLabels: _masteredThisSession,
      );
      // Completion drives the daily-progress transaction. Wait until all
      // answer writes queued before the final card have finished, but still
      // finish the UI even if a callback reports a recoverable persistence
      // error.
      unawaited(
        _attemptWrite.then<void>(
          (_) => widget.onCompleted?.call(summary),
          onError: (Object error, StackTrace stack) {
            widget.onCompleted?.call(summary);
          },
        ),
      );
    }
    setState(() => _finished = true);
  }

  void _next() {
    unawaited(_ttsChannel.invokeMethod<void>('stop'));
    if (widget.mode == LearningMode.matching) {
      _nextMatchingBatch();
      return;
    }
    if (_index == _words.length - 1) {
      _finishSession();
      return;
    }
    setState(() {
      _index++;
      _answered = false;
      _revealed = false;
      _selected = null;
      _matchingMatched.clear();
      _matchingLeft = null;
      _matchingRight = null;
      _matchingWrong = false;
      _answerController.clear();
    });
    unawaited(_persistDraft());
  }

  void _restart() {
    setState(() {
      _index = 0;
      _correct = 0;
      _answered = false;
      _revealed = false;
      _finished = false;
      _saved = false;
      _selected = null;
      _masteredThisSession.clear();
      _answerController.clear();
      _choiceOptionsByIndex.clear();
    });
    unawaited(_clearSavedDraft());
  }

  Future<void> _speak() async {
    try {
      await _ttsChannel.invokeMethod<void>('speak', {'text': _word.english});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiết bị chưa hỗ trợ phát âm từ này.')),
      );
    }
  }

  Future<void> _confirmExit() async {
    if (!mounted || _exitDialogOpen || _finished) {
      if (mounted && _finished) Navigator.of(context).pop();
      return;
    }
    _exitDialogOpen = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thoát phiên học?'),
        content: const Text(
          'Bạn đang học dở. Kết quả chỉ được ghi khi hoàn thành phiên; thoát bây giờ sẽ đóng bài hiện tại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Tiếp tục học'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Rời phiên'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (shouldExit == true && mounted) {
      await _persistDraft();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: Scaffold(
        backgroundColor: context.vocabColors.canvas,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: context.vocabColors.textPrimary,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.mode.icon, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.mode.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: _finished ? _buildResult() : _buildSession(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSession() {
    final colors = context.vocabColors;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Tiến độ phiên học',
                value: 'Câu ${_index + 1} trên ${_words.length}',
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: _words.isEmpty
                        ? 0.0
                        : ((_index + 1) / _words.length).clamp(0.0, 1.0),
                  ),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, val, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: val,
                        minHeight: 10,
                        backgroundColor: colors.surfaceAlt,
                        color: colors.accent,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_index + 1}/${_words.length}',
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, animation) {
              final inAnimation = Tween<Offset>(
                begin: const Offset(0.15, 0.0),
                end: Offset.zero,
              ).animate(animation);
              return SlideTransition(
                position: inAnimation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_index),
              child: SingleChildScrollView(
                child: switch (widget.mode) {
                  LearningMode.flashcard => _buildFlashcard(),
                  LearningMode.matching => _buildMatching(),
                  LearningMode.fillWord => _buildFillWord(),
                  LearningMode.listening => _buildChoiceQuestion(
                    prompt: 'Nghe rồi chọn nghĩa đúng',
                    showEnglish: false,
                  ),
                  LearningMode.translation => _buildChoiceQuestion(
                    prompt: 'Chọn bản dịch đúng',
                    showEnglish: true,
                  ),
                  LearningMode.imageWriting => _buildImageWriting(),
                },
              ),
            ),
          ),
        ),
        if (_isChoiceMode)
          SizedBox(
            // Reserve the feedback area before an answer is selected so the
            // question and options never move when the result appears.
            height: 124,
            child: _answered
                ? Align(
                    alignment: Alignment.topCenter,
                    child: _feedback(_selected?.apiLabel == _word.apiLabel),
                  )
                : const SizedBox.shrink(),
          ),
        if (widget.mode != LearningMode.flashcard)
          SizedBox(
            // Pin the action in a fixed bottom bar slot to eliminate layout jump.
            height: 68,
            child: _answered
                ? Align(
                    alignment: Alignment.center,
                    child: PlayfulButton(
                      onPressed: _next,
                      text: _index == _words.length - 1
                          ? 'Xem kết quả'
                          : 'Câu tiếp theo',
                      icon: _index == _words.length - 1
                          ? Icons.emoji_events_rounded
                          : Icons.arrow_forward_rounded,
                      variant: PlayfulButtonVariant.primary,
                      height: 54,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildFlashcard() {
    final colors = context.vocabColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Column(
      children: [
        Semantics(
          button: true,
          label: _revealed
              ? 'Thẻ ghi nhớ. ${_promptFor(_word)}. Đáp án: ${_answerFor(_word)}.'
              : 'Thẻ ghi nhớ. ${_promptFor(_word)}. Chạm để xem đáp án.',
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _revealed = !_revealed);
          },
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _revealed = !_revealed);
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _revealed ? math.pi : 0),
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                builder: (context, angle, _) {
                  final isFront = angle < (math.pi / 2);
                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0015)
                      ..rotateY(angle),
                    alignment: Alignment.center,
                    child: isFront
                        ? _buildFlashcardFace(
                            isFront: true,
                            content: _promptFor(_word),
                            subText: 'Chạm để lật thẻ ↻',
                            icon: Icons.style_rounded,
                            iconColor: colors.skyPanel,
                            bgColor: colors.surface,
                            bevelColor: colors.borderStrong,
                            textColor: colors.textPrimary,
                            subColor: colors.textSecondary,
                          )
                        : Transform(
                            transform: Matrix4.identity()..rotateY(math.pi),
                            alignment: Alignment.center,
                            child: _buildFlashcardFace(
                              isFront: false,
                              content: _answerFor(_word),
                              subText: _vietnameseToEnglish
                                  ? 'Từ tiếng Anh'
                                  : 'Nghĩa tiếng Việt',
                              icon: Icons.check_circle_rounded,
                              iconColor: colors.accent,
                              bgColor: isDark
                                  ? colors.surfaceAlt
                                  : colors.accentSoft,
                              bevelColor: isDark
                                  ? colors.borderStrong
                                  : colors.accentBevel,
                              textColor: isDark
                                  ? colors.accent
                                  : colors.accentDark,
                              subColor: colors.textSecondary,
                              onAudio: _speak,
                            ),
                          ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (!_revealed)
          PlayfulButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _revealed = true);
            },
            text: 'Lật thẻ',
            icon: Icons.flip_rounded,
            variant: PlayfulButtonVariant.sky,
            height: 54,
          )
        else
          Row(
            children: [
              Expanded(
                child: PlayfulButton(
                  onPressed: () => _recordFlashcard(false),
                  text: 'Chưa nhớ',
                  icon: Icons.refresh_rounded,
                  variant: PlayfulButtonVariant.danger,
                  height: 54,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: PlayfulButton(
                  onPressed: () => _recordFlashcard(true),
                  text: 'Đã nhớ',
                  icon: Icons.star_rounded,
                  variant: PlayfulButtonVariant.primary,
                  height: 54,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFlashcardFace({
    required bool isFront,
    required String content,
    required String subText,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color bevelColor,
    required Color textColor,
    required Color subColor,
    VoidCallback? onAudio,
  }) {
    final colors = context.vocabColors;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 330),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.borderStrong, width: 2),
        boxShadow: [
          BoxShadow(
            color: bevelColor.withValues(alpha: 0.5),
            offset: const Offset(0, 6), // Solid 6dp 3D bevel bottom
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: iconColor),
          ),
          const SizedBox(height: 22),
          Text(
            content,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subText,
                style: TextStyle(
                  color: subColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onAudio != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onAudio,
                  icon: Icon(Icons.volume_up_rounded, color: iconColor),
                  tooltip: 'Nghe phát âm',
                  iconSize: 22,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatching() {
    final batch = _matchingBatch;
    final colors = context.vocabColors;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.borderStrong, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.borderStrong.withValues(alpha: 0.35),
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 20,
                    color: colors.skyPanel,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chạm một nghĩa và một từ để ghép',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Nghĩa',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final word in batch)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _matchingButton(
                              label: word.vietnamese,
                              selected:
                                  _matchingLeft?.apiLabel == word.apiLabel,
                              matched: _matchingMatched.contains(word.apiLabel),
                              onTap: () => _selectMatchingLeft(word),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Từ tiếng Anh',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final word in _matchingRightOptions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _matchingButton(
                              label: word.english,
                              selected:
                                  _matchingRight?.apiLabel == word.apiLabel,
                              matched: _matchingMatched.contains(word.apiLabel),
                              onTap: () => _selectMatchingRight(word),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_matchingWrong)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: colors.errorText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Chưa khớp — thử lại',
                        style: TextStyle(
                          color: colors.errorText,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_answered)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.stars_rounded,
                        size: 20,
                        color: colors.accentDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Đã ghép đủ nhóm này',
                        style: TextStyle(
                          color: colors.accentDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _matchingButton({
    required String label,
    required bool selected,
    required bool matched,
    required VoidCallback onTap,
  }) {
    final colors = context.vocabColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color background;
    final Color borderColor;
    final Color textColor;
    final Color bevelColor;
    final double bevelHeight;

    if (matched) {
      background = isDark ? colors.surfaceAlt : colors.accentSoft;
      borderColor = isDark
          ? colors.accent
          : colors.accentDark.withValues(alpha: 0.5);
      textColor = isDark ? colors.accent : colors.accentDark;
      bevelColor = Colors.transparent;
      bevelHeight = 0;
    } else if (selected) {
      background = isDark
          ? colors.surfaceAlt
          : colors.skyPanel.withValues(alpha: 0.18);
      borderColor = colors.skyPanel;
      textColor = colors.textPrimary;
      bevelColor = colors.skyPanelBevel;
      bevelHeight = 2;
    } else {
      background = colors.surface;
      borderColor = colors.borderStrong;
      textColor = colors.textPrimary;
      bevelColor = colors.borderStrong;
      bevelHeight = 4;
    }

    return Semantics(
      button: true,
      enabled: !matched,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: matched ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: _ShakeWrapper(
          shake: _matchingWrong && selected,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: selected ? 2.5 : 2),
              boxShadow: bevelHeight > 0
                  ? [
                      BoxShadow(
                        color: bevelColor.withValues(alpha: 0.45),
                        offset: Offset(0, bevelHeight),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                if (matched)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: textColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceQuestion({
    required String prompt,
    required bool showEnglish,
  }) {
    final isListening = widget.mode == LearningMode.listening;
    final colors = context.vocabColors;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.borderStrong, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.borderStrong.withValues(alpha: 0.35),
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  prompt,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (showEnglish) ...[
                const SizedBox(height: 18),
                Text(
                  _promptFor(_word),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
              if (isListening) ...[
                const SizedBox(height: 20),
                PlayfulButton(
                  onPressed: _speak,
                  text: 'Nghe từ',
                  icon: Icons.volume_up_rounded,
                  variant: PlayfulButtonVariant.sky,
                  height: 52,
                  width: 170,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final option in _options())
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _answerButton(option),
          ),
      ],
    );
  }

  Widget _answerButton(VocabularyWord option) {
    final colors = context.vocabColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCorrect = _answered && option.apiLabel == _word.apiLabel;
    final isWrongSelection =
        _answered && option.apiLabel == _selected?.apiLabel;

    Color background = colors.surface;
    Color borderColor = colors.borderStrong;
    Color textColor = colors.textPrimary;
    Color bevelColor = colors.borderStrong;
    double bevelHeight = 4;
    IconData? trailingIcon;
    Color? iconColor;

    if (isCorrect) {
      background = isDark ? colors.surfaceAlt : colors.feedbackCorrectBg;
      borderColor = colors.accentDark;
      textColor = colors.accentDark;
      bevelColor = colors.accentBevel;
      bevelHeight = 4;
      trailingIcon = Icons.check_circle_rounded;
      iconColor = colors.accentDark;
    } else if (isWrongSelection) {
      background = isDark ? colors.surfaceAlt : colors.feedbackWrongBg;
      borderColor = colors.errorBevel;
      textColor = colors.errorText;
      bevelColor = colors.errorBevel;
      bevelHeight = 4;
      trailingIcon = Icons.cancel_rounded;
      iconColor = colors.errorText;
    } else if (_answered) {
      background = colors.surface.withValues(alpha: 0.6);
      borderColor = colors.border;
      textColor = colors.textSecondary;
      bevelHeight = 0;
    }

    final answerText = _answerFor(option);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      button: true,
      enabled: !_answered,
      label: answerText,
      child: GestureDetector(
        onTap: _answered ? null : () => _select(option),
        behavior: HitTestBehavior.opaque,
        child: _ShakeWrapper(
          shake: isWrongSelection,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: borderColor,
                width: (isCorrect || isWrongSelection) ? 2.5 : 2,
              ),
              boxShadow: bevelHeight > 0
                  ? [
                      BoxShadow(
                        color: bevelColor.withValues(alpha: 0.35),
                        offset: Offset(0, bevelHeight),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    answerText,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.6, end: 1.0),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.elasticOut,
                    builder: (context, s, ch) => Transform.scale(
                      scale: reduceMotion ? 1.0 : s,
                      child: ch,
                    ),
                    child: Icon(trailingIcon, color: iconColor, size: 24),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFillWord() {
    final colors = context.vocabColors;
    final correct =
        _answered &&
        _answerController.text.trim().toLowerCase() ==
            _answerFor(_word).toLowerCase();
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.borderStrong, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.borderStrong.withValues(alpha: 0.35),
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: 38,
                  color: colors.accentDark,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _promptFor(_word),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _answerController,
                enabled: !_answered,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
                onSubmitted: (_) => _checkFillWord(),
                decoration: InputDecoration(
                  hintText: _vietnameseToEnglish
                      ? 'Nhập từ tiếng Anh'
                      : 'Nhập nghĩa tiếng Việt',
                  filled: true,
                  fillColor: colors.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: colors.borderStrong,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: colors.skyPanel, width: 2.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(color: colors.border, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PlayfulButton(
                onPressed: _answered ? null : _checkFillWord,
                text: 'Kiểm tra',
                icon: Icons.check_rounded,
                variant: PlayfulButtonVariant.primary,
                height: 52,
              ),
            ],
          ),
        ),
        if (_answered) ...[
          const SizedBox(height: 14),
          _feedback(correct),
          if (!correct)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.border, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_rounded,
                    size: 20,
                    color: colors.goldStreak,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Đáp án: ${_answerFor(_word)}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildImageWriting() {
    final colors = context.vocabColors;
    final imageUrl = _word.imageUrl?.trim();
    final localImagePath = _word.localImagePath?.trim();
    final hasOfflineImage =
        (localImagePath != null && localImagePath.isNotEmpty) ||
        (imageUrl != null && imageUrl.startsWith('assets/'));
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 230),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.borderStrong, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.borderStrong.withValues(alpha: 0.35),
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: imageUrl == null || imageUrl.isEmpty || !hasOfflineImage
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 54,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ảnh chưa có trong gói offline.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image(
                    image: localImagePath != null && localImagePath.isNotEmpty
                        ? FileImage(File(localImagePath))
                        : AssetImage(imageUrl),
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    semanticLabel: 'Ảnh minh họa',
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 250,
                      child: Center(
                        child: Text('Không tải được ảnh trong gói hiện tại.'),
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Text(
          'Nhìn hình, viết từ tiếng Anh',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _answerController,
          enabled: !_answered && hasOfflineImage,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
          onSubmitted: (_) => _checkFillWord(),
          decoration: InputDecoration(
            hintText: 'Nhập từ tiếng Anh',
            filled: true,
            fillColor: colors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: colors.borderStrong, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: colors.skyPanel, width: 2.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: colors.border, width: 1.5),
            ),
          ),
        ),
        if (hasOfflineImage && !_answered) ...[
          const SizedBox(height: 14),
          PlayfulButton(
            onPressed: _checkFillWord,
            text: 'Kiểm tra',
            icon: Icons.check_rounded,
            variant: PlayfulButtonVariant.primary,
            height: 52,
          ),
        ],
        if (_answered)
          _feedback(
            _answerController.text.trim().toLowerCase() ==
                _word.english.toLowerCase(),
          ),
      ],
    );
  }

  Widget _feedback(bool correct) {
    final colors = context.vocabColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bgColor = correct
        ? (isDark ? colors.surfaceAlt : colors.feedbackCorrectBg)
        : (isDark ? colors.surfaceAlt : colors.feedbackWrongBg);
    final textColor = correct
        ? (isDark ? colors.textPrimary : colors.feedbackCorrectText)
        : (isDark ? colors.errorText : colors.feedbackWrongText);
    final borderColor = correct ? colors.accentBevel : colors.errorBevel;
    final bevelColor = correct ? colors.accentBevel : colors.errorBevel;

    final feedbackCard = Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: bevelColor.withValues(alpha: 0.35),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          MayAnswerFeedback(
            key: ValueKey('may-feedback-$_index-$correct'),
            correct: correct,
          ),
          const SizedBox(width: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.6, end: 1.0),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.elasticOut,
            builder: (context, scaleVal, child) {
              return Transform.scale(
                scale: reduceMotion ? 1.0 : scaleVal,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                correct
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                color: textColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  correct ? 'Chính xác!' : 'Chưa đúng, hãy thử từ tiếp theo',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  correct
                      ? 'Tuyệt vời! Tiếp tục phát huy nhé 🌟'
                      : 'Đừng nản lòng, cùng thử tiếp nhé! 💪',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (reduceMotion) return feedbackCard;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        return Opacity(
          opacity: anim,
          child: Transform.translate(
            offset: Offset(0, (1 - anim) * 10),
            child: child,
          ),
        );
      },
      child: feedbackCard,
    );
  }

  Widget _buildResult() {
    final percent = (_correct / _words.length * 100).round();
    final colors = context.vocabColors;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const _ConfettiBurst(),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.5, end: 1.0),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colors.goldStreak.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.goldStreak, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: colors.goldStreakBevel.withValues(alpha: 0.3),
                      offset: const Offset(0, 6),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: const MayMascot(
                  size: 96,
                  animation: MayAnimation.completeCelebrate,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Hoàn thành!',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bạn nhớ $_correct/${_words.length} từ ($percent%)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 28),
        PlayfulButton(
          onPressed: _restart,
          text: 'Học lại',
          icon: Icons.replay_rounded,
          variant: PlayfulButtonVariant.primary,
          height: 54,
        ),
        const SizedBox(height: 12),
        PlayfulButton(
          onPressed: () => Navigator.pop(context),
          text: 'Về trang chủ',
          icon: Icons.home_rounded,
          variant: PlayfulButtonVariant.neutral,
          height: 50,
        ),
      ],
    );
  }
}

class _ShakeWrapper extends StatelessWidget {
  final bool shake;
  final Widget child;

  const _ShakeWrapper({required this.shake, required this.child});

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!shake || reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey<bool>(shake),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      builder: (context, val, ch) {
        // 3 gentle oscillations (~300ms, 4dp amplitude)
        final offset = math.sin(val * math.pi * 6) * 4.0;
        return Transform.translate(offset: Offset(offset, 0), child: ch);
      },
      child: child,
    );
  }
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst();

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    final rng = math.Random(42);
    // Strictly design tokens
    const colors = [
      AppColors.blue,
      AppColors.gold,
      AppColors.coral,
      AppColors.purple,
      AppColors.green,
    ];
    _particles = List.generate(16, (i) {
      final angle = (i / 16) * 2 * math.pi + (rng.nextDouble() - 0.5) * 0.3;
      final speed = 70.0 + rng.nextDouble() * 60.0;
      final size = 4.0 + rng.nextDouble() * 4.0;
      final color = colors[i % colors.length];
      return _ConfettiParticle(
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 25.0,
        size: size,
        color: color,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.value == 0 || _controller.value == 1.0) {
          return const SizedBox.shrink();
        }
        return CustomPaint(
          size: const Size(180, 180),
          painter: _ConfettiPainter(
            progress: _controller.value,
            particles: _particles,
          ),
        );
      },
    );
  }
}

class _ConfettiParticle {
  final double vx;
  final double vy;
  final double size;
  final Color color;

  const _ConfettiParticle({
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      paint.color = p.color.withValues(alpha: alpha);
      final dx = center.dx + p.vx * progress;
      final dy = center.dy + p.vy * progress + 40 * progress * progress;
      canvas.drawCircle(Offset(dx, dy), p.size * (1.0 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
