import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'vocabulary_data.dart';

enum LearningMode { flashcard, matching, fillWord, listening }

extension LearningModeInfo on LearningMode {
  String get title => switch (this) {
    LearningMode.flashcard => 'Flashcard',
    LearningMode.matching => 'Ghép hình',
    LearningMode.fillWord => 'Điền từ',
    LearningMode.listening => 'Nghe & chọn',
  };

  String get icon => switch (this) {
    LearningMode.flashcard => '🃏',
    LearningMode.matching => '🧩',
    LearningMode.fillWord => '✏️',
    LearningMode.listening => '🎧',
  };
}

class LearningScreen extends StatefulWidget {
  final LearningMode mode;

  const LearningScreen({super.key, required this.mode});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  static const _navy = Color(0xFF1A1A2E);
  static const _mint = Color(0xFF66FFCC);
  static const _indigo = Color(0xFF5B56F0);
  static const _coral = Color(0xFFFF6B6B);

  static const _ttsChannel = MethodChannel('vocab_vision/tts');

  final _answerController = TextEditingController();

  int _index = 0;
  int _correct = 0;
  bool _answered = false;
  bool _revealed = false;
  bool _finished = false;
  VocabularyWord? _selected;

  VocabularyWord get _word => vocabularyWords[_index];

  @override
  void dispose() {
    _answerController.dispose();
    unawaited(_ttsChannel.invokeMethod<void>('stop'));
    super.dispose();
  }

  List<VocabularyWord> _options() {
    final raw = <VocabularyWord>[
      _word,
      vocabularyWords[(_index + 3) % vocabularyWords.length],
      vocabularyWords[(_index + 7) % vocabularyWords.length],
      vocabularyWords[(_index + 11) % vocabularyWords.length],
    ];
    final shift = _index % raw.length;
    return [...raw.sublist(shift), ...raw.sublist(0, shift)];
  }

  void _select(VocabularyWord selected) {
    if (_answered) return;
    setState(() {
      _selected = selected;
      _answered = true;
      if (selected.apiLabel == _word.apiLabel) _correct++;
    });
  }

  void _checkFillWord() {
    if (_answered || _answerController.text.trim().isEmpty) return;
    final answer = _answerController.text.trim().toLowerCase();
    setState(() {
      _answered = true;
      if (answer == _word.english.toLowerCase()) _correct++;
    });
  }

  void _recordFlashcard(bool remembered) {
    if (remembered) _correct++;
    _next();
  }

  void _next() {
    unawaited(_ttsChannel.invokeMethod<void>('stop'));
    if (_index == vocabularyWords.length - 1) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _answered = false;
      _revealed = false;
      _selected = null;
      _answerController.clear();
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _correct = 0;
      _answered = false;
      _revealed = false;
      _finished = false;
      _selected = null;
      _answerController.clear();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8FFF8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _navy,
        elevation: 0,
        title: Text('${widget.mode.icon} ${widget.mode.title}'),
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
    );
  }

  Widget _buildSession() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_index + 1) / vocabularyWords.length,
                  minHeight: 10,
                  backgroundColor: Colors.white,
                  color: _indigo,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_index + 1}/${vocabularyWords.length}',
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
          child: SingleChildScrollView(
            child: switch (widget.mode) {
              LearningMode.flashcard => _buildFlashcard(),
              LearningMode.matching => _buildChoiceQuestion(
                prompt: 'Ghép từ với hình và nghĩa đúng',
                showEnglish: true,
              ),
              LearningMode.fillWord => _buildFillWord(),
              LearningMode.listening => _buildChoiceQuestion(
                prompt: 'Nghe rồi chọn nghĩa đúng',
                showEnglish: false,
              ),
            },
          ),
        ),
        if (_answered && widget.mode != LearningMode.flashcard) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _index == vocabularyWords.length - 1
                    ? 'Xem kết quả'
                    : 'Câu tiếp theo',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFlashcard() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _revealed = !_revealed),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 310),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_mint, Color(0xFFB7FFE9)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(color: Color(0x245B56F0), blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_word.emoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 20),
                Text(
                  _word.english,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedOpacity(
                  opacity: _revealed ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    _revealed ? _word.vietnamese : 'Chạm để xem nghĩa',
                    style: const TextStyle(
                      color: _indigo,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (!_revealed)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => setState(() => _revealed = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _indigo,
                foregroundColor: Colors.white,
              ),
              child: const Text('Lật thẻ'),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _recordFlashcard(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: _coral,
                    side: const BorderSide(color: _coral),
                  ),
                  child: const Text('Chưa nhớ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _recordFlashcard(true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Đã nhớ'),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildChoiceQuestion({
    required String prompt,
    required bool showEnglish,
  }) {
    final isListening = widget.mode == LearningMode.listening;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Text(prompt, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 18),
              Text(_word.emoji, style: const TextStyle(fontSize: 62)),
              if (showEnglish) ...[
                const SizedBox(height: 10),
                Text(
                  _word.english,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              if (isListening) ...[
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _speak,
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Nghe từ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final option in _options())
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _answerButton(option),
          ),
        if (_answered) _feedback(_selected?.apiLabel == _word.apiLabel),
      ],
    );
  }

  Widget _answerButton(VocabularyWord option) {
    Color background = Colors.white;
    Color foreground = _navy;
    if (_answered && option.apiLabel == _word.apiLabel) {
      background = const Color(0xFFBDF4D7);
      foreground = const Color(0xFF087443);
    } else if (_answered && option.apiLabel == _selected?.apiLabel) {
      background = const Color(0xFFFFD1D1);
      foreground = const Color(0xFFA82020);
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _answered ? null : () => _select(option),
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background,
          disabledForegroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          side: BorderSide(color: foreground.withValues(alpha: 0.25)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                option.vietnamese,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFillWord() {
    final correct =
        _answered &&
        _answerController.text.trim().toLowerCase() ==
            _word.english.toLowerCase();
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              Text(_word.emoji, style: const TextStyle(fontSize: 68)),
              const SizedBox(height: 12),
              Text(
                _word.vietnamese,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _answerController,
                enabled: !_answered,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onSubmitted: (_) => _checkFillWord(),
                decoration: InputDecoration(
                  hintText: 'Nhập từ tiếng Anh',
                  filled: true,
                  fillColor: const Color(0xFFF4F4FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _answered ? null : _checkFillWord,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: _indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Kiểm tra'),
                ),
              ),
            ],
          ),
        ),
        if (_answered) ...[
          const SizedBox(height: 14),
          _feedback(correct),
          if (!correct)
            Text(
              'Đáp án: ${_word.english}',
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w800),
            ),
        ],
      ],
    );
  }

  Widget _feedback(bool correct) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      correct ? '🎉 Chính xác!' : '💪 Chưa đúng, thử từ tiếp theo nhé!',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: correct ? const Color(0xFF087443) : _coral,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _buildResult() {
    final percent = (_correct / vocabularyWords.length * 100).round();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🏆', style: TextStyle(fontSize: 82)),
        const SizedBox(height: 16),
        const Text(
          'Hoàn thành!',
          style: TextStyle(
            color: _navy,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bạn nhớ $_correct/${vocabularyWords.length} từ ($percent%)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54, fontSize: 16),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _restart,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _indigo,
              foregroundColor: Colors.white,
            ),
            child: const Text('Học lại'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Về trang chủ'),
        ),
      ],
    );
  }
}
