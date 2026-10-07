import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'camera_buddy.dart';
export 'playful_button.dart';
export 'staggered_entrance.dart';

/// Centralized design tokens for the single unified dark theme
abstract final class AppColors {
  // Neutrals
  static const background = Color(0xFF131F27);
  static const canvas = Color(0xFF131F27);
  static const card = Color(0xFF1B2A35);
  static const surface = Color(0xFF1B2A35);
  static const surfaceAlt = Color(0xFF223444);
  static const bar = Color(0xFF0F1A21);
  static const cardBorder = Color(0xFF2C3E4C);
  static const cardEdge = Color(0xFF0E171E);

  // Text & Icons
  static const text = Color(0xFFFFFFFF);
  static const ink = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFA9BAC6);
  static const secondaryText = Color(0xFFA9BAC6);
  static const secondaryInk = Color(0xFFA9BAC6);
  static const inactiveIcon = Color(0xFF8FA5B4);
  static const unselectedNav = Color(0xFF8FA5B4);
  static const locked = Color(0xFF4A5D6B);

  // Blue: #2A7BE4 (buttons with text #1F6FD6), edge #1B57AE, tint #1B3A5C, accent text #6FB3FF
  static const blue = Color(0xFF2A7BE4);
  static const blueButtonText = Color(0xFF1F6FD6);
  static const blueEdge = Color(0xFF1B57AE);
  static const blueTint = Color(0xFF1B3A5C);
  static const blueAccentText = Color(0xFF6FB3FF);
  static const primary = Color(0xFF2A7BE4);
  static const primaryTeal = Color(0xFF2A7BE4);
  static const primaryTealFill = Color(0xFF2A7BE4);
  static const primaryTealEdge = Color(0xFF1B57AE);
  static const primaryTealTint = Color(0xFF1B3A5C);
  static const heroEdge = Color(0xFF1B57AE);
  static const primaryTealDark = Color(0xFF6FB3FF);
  static const textOnTealTint = Color(0xFF6FB3FF);

  // Mascot (allowed by prompt)
  static const mascotBody = Color(0xFF19B7A2);
  static const mascotOutline = Color(0xFF0A7F72);

  // Gold: #FFC83D, edge #D9950F, ink #3A2600
  static const gold = Color(0xFFFFC83D);
  static const goldEdge = Color(0xFFD9950F);
  static const goldInk = Color(0xFF3A2600);
  static const sunFill = Color(0xFFFFC83D);
  static const sunEdge = Color(0xFFD9950F);
  static const sunTint = Color(0xFF1B2A35);
  static const textOnSun = Color(0xFF3A2600);

  // Purple: #8A57E8, edge #5F35B8
  static const purple = Color(0xFF8A57E8);
  static const purpleEdge = Color(0xFF5F35B8);

  // Orange: #FF9A3D, edge #D9741A, ink #3A1D00
  static const orange = Color(0xFFFF9A3D);
  static const orangeEdge = Color(0xFFD9741A);
  static const orangeInk = Color(0xFF3A1D00);

  // Green: #4CCB57, edge #2F9A3B, ink #0A2A12
  static const green = Color(0xFF4CCB57);
  static const greenEdge = Color(0xFF2F9A3B);
  static const greenInk = Color(0xFF0A2A12);

  // Coral: #FF5A5F, edge #C93A40, ink #2A0508
  static const coral = Color(0xFFFF5A5F);
  static const coralEdge = Color(0xFFC93A40);
  static const coralInk = Color(0xFF2A0508);
  static const coralFill = Color(0xFFFF5A5F);
  static const coralTint = Color(0xFF1B2A35);
  static const coralDark = Color(0xFFFF5A5F);
  static const textOnCoralTint = Color(0xFFFF5A5F);

  // Sky
  static const skyFill = Color(0xFF2A7BE4);
  static const skyEdge = Color(0xFF1B57AE);
  static const skyBorder = Color(0xFF2C3E4C);
  static const skyTint = Color(0xFF1B3A5C);
  static const skyDark = Color(0xFF6FB3FF);
  static const textOnSkyTint = Color(0xFF6FB3FF);

  // Lilac
  static const lilacFill = Color(0xFF8A57E8);
  static const lilacEdge = Color(0xFF5F35B8);
  static const lilacTint = Color(0xFF1B2A35);
  static const lilacDark = Color(0xFF8A57E8);
  static const textOnLilacTint = Color(0xFF8A57E8);

  // Navigation
  static const navBarBackground = Color(0xFF0F1A21);
  static const navBarTopLine = Color(0xFF2C3E4C);
  static const navSelectedPill = Color(0xFF1B3A5C);
  static const navSelectedIcon = Color(0xFF6FB3FF);
  static const navUnselectedIcon = Color(0xFF8FA5B4);
  static const cameraGold = Color(0xFFFFC83D);
  static const cameraGoldEdge = Color(0xFFD9950F);
  static const cameraGoldHighlight = Color(0xFFFFE18A);
  static const cameraCream = Color(0xFFFFF3C7);
  static const cameraLensBlue = Color(0xFF2A7BE4);
  static const cameraBodyDark = Color(0xFF3A2600);
}

/// Semantic colors used by the product UI.
@immutable
class VocabColors extends ThemeExtension<VocabColors> {
  final Color canvas;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color borderStrong;
  final Color locked;

  // Primary
  final Color accent;
  final Color accentBevel;
  final Color accentDark;
  final Color accentSoft;
  final Color tealTextOnTint;

  // Sun / Gold
  final Color goldStreak;
  final Color goldStreakBevel;
  final Color sunTint;
  final Color sunText;

  // Sky / Blue
  final Color skyTint;
  final Color skyBorder;
  final Color skyText;
  final Color skyPanel;
  final Color skyPanelBevel;

  // Coral
  final Color coralFill;
  final Color coralEdge;
  final Color coralTint;
  final Color coralText;

  // Lilac / Purple
  final Color lilacTint;
  final Color lilacText;

  // Hero & Panels
  final Color primaryPanel;
  final Color heroEdge;
  final Color onPrimaryPanel;

  // Navigation
  final Color unselectedNav;

  // Warning & Error legacy compatibility
  final Color warningSurface;
  final Color warningText;
  final Color errorSurface;
  final Color errorText;

  // Feedback
  final Color feedbackCorrectBg;
  final Color feedbackCorrectText;
  final Color feedbackWrongBg;
  final Color feedbackWrongText;

  // Buttons & Actions
  final Color cardShadow;
  final Color primaryAction;
  final Color onPrimaryAction;

  // Categories
  final Color categorySchoolFill;
  final Color categorySchoolIcon;
  final Color categoryAnimalFill;
  final Color categoryAnimalIcon;
  final Color categoryFruitFill;
  final Color categoryFruitIcon;
  final Color categoryOtherFill;
  final Color categoryOtherIcon;

  const VocabColors({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.borderStrong,
    required this.locked,
    required this.accent,
    required this.accentBevel,
    required this.accentDark,
    required this.accentSoft,
    required this.tealTextOnTint,
    required this.goldStreak,
    required this.goldStreakBevel,
    required this.sunTint,
    required this.sunText,
    required this.skyTint,
    required this.skyBorder,
    required this.skyText,
    required this.skyPanel,
    required this.skyPanelBevel,
    required this.coralFill,
    required this.coralEdge,
    required this.coralTint,
    required this.coralText,
    required this.lilacTint,
    required this.lilacText,
    required this.primaryPanel,
    required this.heroEdge,
    required this.onPrimaryPanel,
    required this.unselectedNav,
    required this.warningSurface,
    required this.warningText,
    required this.errorSurface,
    required this.errorText,
    required this.feedbackCorrectBg,
    required this.feedbackCorrectText,
    required this.feedbackWrongBg,
    required this.feedbackWrongText,
    required this.cardShadow,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.categorySchoolFill,
    required this.categorySchoolIcon,
    required this.categoryAnimalFill,
    required this.categoryAnimalIcon,
    required this.categoryFruitFill,
    required this.categoryFruitIcon,
    required this.categoryOtherFill,
    required this.categoryOtherIcon,
  });

  Color get errorBevel => coralEdge;

  static const dark = VocabColors(
    canvas: Color(0xFF131F27),
    surface: Color(0xFF1B2A35),
    surfaceAlt: Color(0xFF223444),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA9BAC6),
    border: Color(0xFF2C3E4C),
    borderStrong: Color(0xFF0E171E),
    locked: Color(0xFF4A5D6B),

    // Primary: Blue
    accent: Color(0xFF2A7BE4),
    accentBevel: Color(0xFF1B57AE),
    accentDark: Color(0xFF1B57AE),
    accentSoft: Color(0xFF1B3A5C),
    tealTextOnTint: Color(0xFF6FB3FF),

    // Sun
    goldStreak: Color(0xFFFFC83D),
    goldStreakBevel: Color(0xFFD9950F),
    sunTint: Color(0xFF1B2A35),
    sunText: Color(0xFF3A2600),

    // Sky / Blue
    skyTint: Color(0xFF1B3A5C),
    skyBorder: Color(0xFF2C3E4C),
    skyText: Color(0xFF6FB3FF),
    skyPanel: Color(0xFF1B3A5C),
    skyPanelBevel: Color(0xFF1B57AE),

    // Coral
    coralFill: Color(0xFFFF5A5F),
    coralEdge: Color(0xFFC93A40),
    coralTint: Color(0xFF1B2A35),
    coralText: Color(0xFFFF5A5F),

    // Lilac
    lilacTint: Color(0xFF1B2A35),
    lilacText: Color(0xFF8A57E8),

    // Hero: Solid Blue
    primaryPanel: Color(0xFF2A7BE4),
    heroEdge: Color(0xFF1B57AE),
    onPrimaryPanel: Color(0xFFFFFFFF),
    unselectedNav: Color(0xFF8FA5B4),

    // Warning & Error
    warningSurface: Color(0xFF1B2A35),
    warningText: Color(0xFFFFC83D),
    errorSurface: Color(0xFF1B2A35),
    errorText: Color(0xFFFF5A5F),

    // Feedback
    feedbackCorrectBg: Color(0xFF4CCB57),
    feedbackCorrectText: Color(0xFF0A2A12),
    feedbackWrongBg: Color(0xFFFF5A5F),
    feedbackWrongText: Color(0xFFFFFFFF),

    // Buttons
    cardShadow: Color(0x00000000),
    primaryAction: Color(0xFF2A7BE4),
    onPrimaryAction: Color(0xFFFFFFFF),

    // Categories
    categorySchoolFill: Color(0xFF1B3A5C),
    categorySchoolIcon: Color(0xFF6FB3FF),
    categoryAnimalFill: Color(0xFF1B2A35),
    categoryAnimalIcon: Color(0xFFFF9A3D),
    categoryFruitFill: Color(0xFF1B2A35),
    categoryFruitIcon: Color(0xFF4CCB57),
    categoryOtherFill: Color(0xFF1B2A35),
    categoryOtherIcon: Color(0xFF8A57E8),
  );

  static final light = dark.copyWith(
    canvas: const Color(0xFFF5FAFF),
    surface: Colors.white,
    surfaceAlt: const Color(0xFFEAF2FA),
    textPrimary: const Color(0xFF183047),
    textSecondary: const Color(0xFF52677A),
    border: const Color(0xFFD1E0EE),
    borderStrong: const Color(0xFFB0C7DB),
    locked: const Color(0xFF62788C),
    accentSoft: const Color(0xFFE3F0FF),
    tealTextOnTint: const Color(0xFF1858A0),
    sunTint: const Color(0xFFFFF4CC),
    skyTint: const Color(0xFFE3F0FF),
    skyBorder: const Color(0xFFBAD7F4),
    skyText: const Color(0xFF1858A0),
    skyPanel: const Color(0xFFE3F0FF),
    coralTint: const Color(0xFFFFE9E8),
    coralText: const Color(0xFFA62832),
    lilacTint: const Color(0xFFF0E8FF),
    lilacText: const Color(0xFF6634AE),
    unselectedNav: const Color(0xFF52677A),
    warningSurface: const Color(0xFFFFF4CC),
    warningText: const Color(0xFF715000),
    errorSurface: const Color(0xFFFFE9E8),
    errorText: const Color(0xFFA62832),
    categorySchoolFill: const Color(0xFFE3F0FF),
    categorySchoolIcon: const Color(0xFF1858A0),
    categoryAnimalFill: const Color(0xFFFFEEDB),
    categoryAnimalIcon: const Color(0xFF945000),
    categoryFruitFill: const Color(0xFFE5F6E7),
    categoryFruitIcon: const Color(0xFF246B2D),
    categoryOtherFill: const Color(0xFFF0E8FF),
    categoryOtherIcon: const Color(0xFF6634AE),
  );

  Color get goldText => sunText;
  Color get tealFill => accent;
  Color get tealEdge => accentBevel;
  Color get tealTint => accentSoft;
  Color get sunFill => goldStreak;
  Color get sunEdge => goldStreakBevel;

  @override
  VocabColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? borderStrong,
    Color? locked,
    Color? accent,
    Color? accentBevel,
    Color? accentDark,
    Color? accentSoft,
    Color? tealTextOnTint,
    Color? goldStreak,
    Color? goldStreakBevel,
    Color? sunTint,
    Color? sunText,
    Color? skyTint,
    Color? skyBorder,
    Color? skyText,
    Color? skyPanel,
    Color? skyPanelBevel,
    Color? coralFill,
    Color? coralEdge,
    Color? coralTint,
    Color? coralText,
    Color? lilacTint,
    Color? lilacText,
    Color? primaryPanel,
    Color? heroEdge,
    Color? onPrimaryPanel,
    Color? unselectedNav,
    Color? warningSurface,
    Color? warningText,
    Color? errorSurface,
    Color? errorText,
    Color? feedbackCorrectBg,
    Color? feedbackCorrectText,
    Color? feedbackWrongBg,
    Color? feedbackWrongText,
    Color? cardShadow,
    Color? primaryAction,
    Color? onPrimaryAction,
    Color? categorySchoolFill,
    Color? categorySchoolIcon,
    Color? categoryAnimalFill,
    Color? categoryAnimalIcon,
    Color? categoryFruitFill,
    Color? categoryFruitIcon,
    Color? categoryOtherFill,
    Color? categoryOtherIcon,
  }) => VocabColors(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceAlt: surfaceAlt ?? this.surfaceAlt,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    locked: locked ?? this.locked,
    accent: accent ?? this.accent,
    accentBevel: accentBevel ?? this.accentBevel,
    accentDark: accentDark ?? this.accentDark,
    accentSoft: accentSoft ?? this.accentSoft,
    tealTextOnTint: tealTextOnTint ?? this.tealTextOnTint,
    goldStreak: goldStreak ?? this.goldStreak,
    goldStreakBevel: goldStreakBevel ?? this.goldStreakBevel,
    sunTint: sunTint ?? this.sunTint,
    sunText: sunText ?? this.sunText,
    skyTint: skyTint ?? this.skyTint,
    skyBorder: skyBorder ?? this.skyBorder,
    skyText: skyText ?? this.skyText,
    skyPanel: skyPanel ?? this.skyPanel,
    skyPanelBevel: skyPanelBevel ?? this.skyPanelBevel,
    coralFill: coralFill ?? this.coralFill,
    coralEdge: coralEdge ?? this.coralEdge,
    coralTint: coralTint ?? this.coralTint,
    coralText: coralText ?? this.coralText,
    lilacTint: lilacTint ?? this.lilacTint,
    lilacText: lilacText ?? this.lilacText,
    primaryPanel: primaryPanel ?? this.primaryPanel,
    heroEdge: heroEdge ?? this.heroEdge,
    onPrimaryPanel: onPrimaryPanel ?? this.onPrimaryPanel,
    unselectedNav: unselectedNav ?? this.unselectedNav,
    warningSurface: warningSurface ?? this.warningSurface,
    warningText: warningText ?? this.warningText,
    errorSurface: errorSurface ?? this.errorSurface,
    errorText: errorText ?? this.errorText,
    feedbackCorrectBg: feedbackCorrectBg ?? this.feedbackCorrectBg,
    feedbackCorrectText: feedbackCorrectText ?? this.feedbackCorrectText,
    feedbackWrongBg: feedbackWrongBg ?? this.feedbackWrongBg,
    feedbackWrongText: feedbackWrongText ?? this.feedbackWrongText,
    cardShadow: cardShadow ?? this.cardShadow,
    primaryAction: primaryAction ?? this.primaryAction,
    onPrimaryAction: onPrimaryAction ?? this.onPrimaryAction,
    categorySchoolFill: categorySchoolFill ?? this.categorySchoolFill,
    categorySchoolIcon: categorySchoolIcon ?? this.categorySchoolIcon,
    categoryAnimalFill: categoryAnimalFill ?? this.categoryAnimalFill,
    categoryAnimalIcon: categoryAnimalIcon ?? this.categoryAnimalIcon,
    categoryFruitFill: categoryFruitFill ?? this.categoryFruitFill,
    categoryFruitIcon: categoryFruitIcon ?? this.categoryFruitIcon,
    categoryOtherFill: categoryOtherFill ?? this.categoryOtherFill,
    categoryOtherIcon: categoryOtherIcon ?? this.categoryOtherIcon,
  );

  @override
  VocabColors lerp(covariant VocabColors? other, double t) {
    if (other == null) return this;
    return VocabColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      locked: Color.lerp(locked, other.locked, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentBevel: Color.lerp(accentBevel, other.accentBevel, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      tealTextOnTint: Color.lerp(tealTextOnTint, other.tealTextOnTint, t)!,
      goldStreak: Color.lerp(goldStreak, other.goldStreak, t)!,
      goldStreakBevel: Color.lerp(goldStreakBevel, other.goldStreakBevel, t)!,
      sunTint: Color.lerp(sunTint, other.sunTint, t)!,
      sunText: Color.lerp(sunText, other.sunText, t)!,
      skyTint: Color.lerp(skyTint, other.skyTint, t)!,
      skyBorder: Color.lerp(skyBorder, other.skyBorder, t)!,
      skyText: Color.lerp(skyText, other.skyText, t)!,
      skyPanel: Color.lerp(skyPanel, other.skyPanel, t)!,
      skyPanelBevel: Color.lerp(skyPanelBevel, other.skyPanelBevel, t)!,
      coralFill: Color.lerp(coralFill, other.coralFill, t)!,
      coralEdge: Color.lerp(coralEdge, other.coralEdge, t)!,
      coralTint: Color.lerp(coralTint, other.coralTint, t)!,
      coralText: Color.lerp(coralText, other.coralText, t)!,
      lilacTint: Color.lerp(lilacTint, other.lilacTint, t)!,
      lilacText: Color.lerp(lilacText, other.lilacText, t)!,
      primaryPanel: Color.lerp(primaryPanel, other.primaryPanel, t)!,
      heroEdge: Color.lerp(heroEdge, other.heroEdge, t)!,
      onPrimaryPanel: Color.lerp(onPrimaryPanel, other.onPrimaryPanel, t)!,
      unselectedNav: Color.lerp(unselectedNav, other.unselectedNav, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      feedbackCorrectBg: Color.lerp(
        feedbackCorrectBg,
        other.feedbackCorrectBg,
        t,
      )!,
      feedbackCorrectText: Color.lerp(
        feedbackCorrectText,
        other.feedbackCorrectText,
        t,
      )!,
      feedbackWrongBg: Color.lerp(feedbackWrongBg, other.feedbackWrongBg, t)!,
      feedbackWrongText: Color.lerp(
        feedbackWrongText,
        other.feedbackWrongText,
        t,
      )!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      primaryAction: Color.lerp(primaryAction, other.primaryAction, t)!,
      onPrimaryAction: Color.lerp(onPrimaryAction, other.onPrimaryAction, t)!,
      categorySchoolFill: Color.lerp(
        categorySchoolFill,
        other.categorySchoolFill,
        t,
      )!,
      categorySchoolIcon: Color.lerp(
        categorySchoolIcon,
        other.categorySchoolIcon,
        t,
      )!,
      categoryAnimalFill: Color.lerp(
        categoryAnimalFill,
        other.categoryAnimalFill,
        t,
      )!,
      categoryAnimalIcon: Color.lerp(
        categoryAnimalIcon,
        other.categoryAnimalIcon,
        t,
      )!,
      categoryFruitFill: Color.lerp(
        categoryFruitFill,
        other.categoryFruitFill,
        t,
      )!,
      categoryFruitIcon: Color.lerp(
        categoryFruitIcon,
        other.categoryFruitIcon,
        t,
      )!,
      categoryOtherFill: Color.lerp(
        categoryOtherFill,
        other.categoryOtherFill,
        t,
      )!,
      categoryOtherIcon: Color.lerp(
        categoryOtherIcon,
        other.categoryOtherIcon,
        t,
      )!,
    );
  }
}

extension VocabThemeContext on BuildContext {
  VocabColors get vocabColors =>
      Theme.of(this).extension<VocabColors>() ?? VocabColors.light;
}

/// Helper decoration for "chunky" cards:
/// Surface #1B2A35, 2dp border #2C3E4C with a 4dp bottom edge #0E171E, radius 20, no blurry shadows.
BoxDecoration chunkyCardDecoration({
  required BuildContext context,
  Color? color,
  double radius = 20.0,
}) {
  final colors = context.vocabColors;
  return BoxDecoration(
    color: color ?? colors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colors.border, width: 2),
    boxShadow: [
      BoxShadow(
        color: colors.borderStrong,
        offset: const Offset(0, 4),
        blurRadius: 0,
      ),
    ],
  );
}

/// Chunky card widget with the 2dp border and 4dp solid bottom edge.
class ChunkyCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const ChunkyCard({
    super.key,
    required this.child,
    this.color,
    this.radius = 20.0,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      decoration: chunkyCardDecoration(
        context: context,
        color: color,
        radius: radius,
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

ThemeData buildVocabTheme({
  required Brightness brightness,
  required Color seedColor,
}) {
  final colors = brightness == Brightness.dark
      ? VocabColors.dark
      : VocabColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ).copyWith(
        surface: colors.surface,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.surfaceAlt,
        outline: colors.border,
        primary: colors.accent,
        onPrimary: Colors.white,
        primaryContainer: colors.accentSoft,
        onPrimaryContainer: colors.tealTextOnTint,
        error: colors.coralFill,
        onError: Colors.white,
        errorContainer: colors.coralTint,
        onErrorContainer: colors.coralText,
      );
  final baseText = ThemeData(brightness: brightness, useMaterial3: true)
      .textTheme
      .apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.canvas,
    canvasColor: colors.canvas,
    extensions: <ThemeExtension<dynamic>>[colors],
    textTheme: baseText.copyWith(
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
      bodySmall: baseText.bodySmall?.copyWith(fontWeight: FontWeight.w500),
      labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: baseText.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.canvas,
      foregroundColor: colors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: colors.surface,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      titleTextStyle: baseText.titleLarge?.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border, width: 2),
      ),
      titleTextStyle: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
      contentTextStyle: TextStyle(
        color: colors.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surface,
      selectedColor: colors.accent,
      labelStyle: TextStyle(color: colors.textPrimary),
      side: BorderSide(color: colors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.accent
            : colors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.accentSoft
            : colors.surfaceAlt,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.accent,
      inactiveTrackColor: colors.accentSoft,
      thumbColor: colors.accent,
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border, width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      hintStyle: TextStyle(
        color: colors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: TextStyle(
        color: colors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: colors.textSecondary,
      suffixIconColor: colors.textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.accent, width: 2.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.accentSoft,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? colors.accent
              : colors.unselectedNav,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.accent
              : colors.unselectedNav,
          size: 23,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.surface,
      contentTextStyle: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border, width: 1.5),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.surfaceAlt,
    ),
    dividerTheme: DividerThemeData(color: colors.border),
  );
}
