import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/learning_screen.dart';
import 'package:giao_dien/vocabulary_data.dart';

void main() {
  testWidgets('flashcard semantics does not leak the answer before reveal', (
    tester,
  ) async {
    const word = VocabularyWord(
      apiLabel: 'pencil',
      emoji: '',
      english: 'Pencil',
      vietnamese: 'Bút chì',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: LearningScreen(mode: LearningMode.flashcard, words: [word]),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Thẻ ghi nhớ. Bút chì. Chạm để xem đáp án.',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Pencil'), findsNothing);

    await tester.tap(
      find.bySemanticsLabel('Thẻ ghi nhớ. Bút chì. Chạm để xem đáp án.'),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Thẻ ghi nhớ. Bút chì. Đáp án: Pencil.'),
      findsOneWidget,
    );
  });
}
