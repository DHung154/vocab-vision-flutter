import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/core/theme/app_theme.dart';

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('light palette has a distinct bright canvas', () {
    expect(VocabColors.light.canvas, isNot(VocabColors.dark.canvas));
    expect(VocabColors.light.canvas.computeLuminance(), greaterThan(0.8));
    expect(VocabColors.light.textPrimary.computeLuminance(), lessThan(0.1));
  });
  test('WCAG AA contrast test for all token pairs', () {
    final pairs = <String, (Color fg, Color bg, double minRatio)>{
      'Ink on Background': (AppColors.ink, AppColors.background, 14.5),
      'Secondary Ink on Background': (
        AppColors.secondaryInk,
        AppColors.background,
        6.0,
      ),
      'Ink on Card Surface': (AppColors.ink, AppColors.card, 10.0),
      'Secondary Ink on Card Surface': (
        AppColors.secondaryInk,
        AppColors.card,
        4.5,
      ),
      'Gold Ink on Gold': (AppColors.goldInk, AppColors.gold, 7.0),
      'Orange Ink on Orange': (AppColors.orangeInk, AppColors.orange, 4.5),
      'Green Ink on Green': (AppColors.greenInk, AppColors.green, 4.5),
      'Coral Ink on Coral': (AppColors.coralInk, AppColors.coral, 4.5),
      'Blue Accent Text on Tint': (
        AppColors.blueAccentText,
        AppColors.blueTint,
        4.5,
      ),
      'Blue Accent Text on Surface': (
        AppColors.blueAccentText,
        AppColors.surface,
        4.5,
      ),
      'Inactive Nav Icon on Dark Nav Bar': (
        AppColors.navUnselectedIcon,
        AppColors.navBarBackground,
        4.5,
      ),
      'Selected Nav Icon on Dark Nav Bar': (
        AppColors.navSelectedIcon,
        AppColors.navBarBackground,
        4.5,
      ),
      // Buttons / large UI elements (WCAG AA 3:1 minimum)
      'White on Blue Fill (Button / Hero)': (Colors.white, AppColors.blue, 3.0),
      'White on Purple Fill (Button)': (Colors.white, AppColors.purple, 3.0),
      'White on Coral Fill (Button)': (Colors.white, AppColors.coral, 3.0),
    };

    final failures = <String>[];

    pairs.forEach((name, item) {
      final ratio = _contrast(item.$1, item.$2);
      if (ratio < item.$3) {
        failures.add(
          'FAIL: $name ratio is ${ratio.toStringAsFixed(2)}:1 (required >= ${item.$3}:1)',
        );
      }
    });

    if (failures.isNotEmpty) {
      // ignore: avoid_print
      print('=== CONTRAST FAILURES ===\n${failures.join('\n')}');
    }

    pairs.forEach((name, item) {
      final ratio = _contrast(item.$1, item.$2);
      expect(
        ratio,
        greaterThanOrEqualTo(item.$3),
        reason: 'Contrast for $name is ${ratio.toStringAsFixed(2)}:1',
      );
    });
  });

  test('semantic body text stays readable in both themes', () {
    for (final colors in [VocabColors.light, VocabColors.dark]) {
      expect(
        _contrast(colors.textPrimary, colors.canvas),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.textSecondary, colors.canvas),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.textPrimary, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.textSecondary, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.onPrimaryPanel, colors.primaryPanel),
        greaterThanOrEqualTo(3.0), // WCAG AA large element / button threshold
      );
    }
  });

  testWidgets('theme extension is available to native surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVocabTheme(
          brightness: Brightness.dark,
          seedColor: AppColors.primaryTeal,
        ),
        home: Builder(
          builder: (context) => ColoredBox(
            color: context.vocabColors.canvas,
            child: Text(
              'Dark surface',
              style: TextStyle(color: context.vocabColors.textPrimary),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Dark surface'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('Dark surface'))).brightness,
      Brightness.dark,
    );
  });
}
