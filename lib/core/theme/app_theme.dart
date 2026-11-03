import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// TechDaily design system.
///
/// One confident palette: near-black ink, warm off-white paper and a single
/// hot accent (electric orange). Category colours are only used for small
/// tags. Typography: Space Grotesk for display/headlines, Inter for body.
/// Both fonts are bundled in `assets/fonts` so web never flashes a fallback.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Fonts
  // ---------------------------------------------------------------------------
  static const String displayFont = 'SpaceGrotesk';
  static const String bodyFont = 'Inter';

  /// Tabular figures: digits keep a fixed width and never look "spaced out".
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  // ---------------------------------------------------------------------------
  // Core palette
  // ---------------------------------------------------------------------------
  static const Color ink = Color(0xFF0B0B0F);
  static const Color paper = Color(0xFFF7F5F0);
  static const Color accent = Color(0xFFFF5A1F); // electric orange
  static const Color accentDark = Color(0xFFFF6A33); // slightly lifted for dark bg
  static const Color live = Color(0xFFE5262B);

  // Light tokens
  static const Color lightBg = paper;
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEFECE4);
  static const Color lightInk = ink;
  static const Color lightInkMuted = Color(0xFF5C5A55);
  static const Color lightBorder = Color(0xFFE3DFD5);

  // Dark tokens
  static const Color darkBg = ink;
  static const Color darkSurface = Color(0xFF15151B);
  static const Color darkSurfaceAlt = Color(0xFF1E1E26);
  static const Color darkInk = Color(0xFFF4F2EC);
  static const Color darkInkMuted = Color(0xFFB9B5AD); // 8.9:1 on surface
  static const Color darkBorder = Color(0xFF2E2E38);

  // Legacy names kept so older widgets pick up the new accent automatically.
  static const Color cyberCyan = accentDark;
  static const Color neonBlue = accent;
  static const Color electricViolet = accent;
  static const Color electricCrimson = live;
  static const Color lightPrimary = accent;
  static const Color lightSecondary = ink;
  static const Color accentCrimson = live;
  static const Color darkPrimary = accentDark;
  static const Color darkSecondary = darkInk;

  /// Category colours — used for small tags and fallback artwork only.
  static const Map<String, Color> categoryAccents = {
    'ai & machine learning': Color(0xFF7C5CFF),
    'ai': Color(0xFF7C5CFF),
    'software': Color(0xFF0EA5A4),
    'dev': Color(0xFF0EA5A4),
    'hardware': Color(0xFFE59E0B),
    'semiconductors': Color(0xFFE59E0B),
    'smartphones': Color(0xFF3B82F6),
    'mobile': Color(0xFF3B82F6),
    'cybersecurity': Color(0xFF16A34A),
    'cloud': Color(0xFF0EA5E9),
    'startups': Color(0xFFEC4899),
    'startups & vc': Color(0xFFEC4899),
    'science': Color(0xFF8B5CF6),
    'biotech': Color(0xFF8B5CF6),
    'space': Color(0xFF6366F1),
    'companies': Color(0xFF64748B),
  };

  static Color getCategoryAccent(String category, {bool isDark = true}) {
    final key = category.trim().toLowerCase();
    return categoryAccents[key] ?? (isDark ? accentDark : accent);
  }

  static IconData categoryIcon(String category) {
    switch (category.trim().toLowerCase()) {
      case 'ai & machine learning':
      case 'ai':
        return Icons.psychology_outlined;
      case 'software':
      case 'dev':
        return Icons.code_rounded;
      case 'hardware':
      case 'semiconductors':
        return Icons.memory_outlined;
      case 'smartphones':
      case 'mobile':
        return Icons.smartphone_outlined;
      case 'cybersecurity':
        return Icons.shield_outlined;
      case 'cloud':
        return Icons.cloud_outlined;
      case 'startups':
      case 'startups & vc':
        return Icons.rocket_outlined;
      case 'science':
      case 'biotech':
        return Icons.biotech_outlined;
      case 'space':
        return Icons.rocket_launch_outlined;
      case 'companies':
        return Icons.business_outlined;
      default:
        return Icons.bolt_rounded;
    }
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color accentOf(BuildContext context) =>
      isDark(context) ? accentDark : accent;

  static Color mutedOf(BuildContext context) =>
      isDark(context) ? darkInkMuted : lightInkMuted;

  static Color borderOf(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  static Color surfaceAltOf(BuildContext context) =>
      isDark(context) ? darkSurfaceAlt : lightSurfaceAlt;

  // ---------------------------------------------------------------------------
  // Text helpers
  // ---------------------------------------------------------------------------
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.12,
  }) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: -0.4,
      color: color,
    );
  }

  /// Small uppercase label (kicker). Letter spacing is only used on words,
  /// never on numbers.
  static TextStyle kicker({Color? color, double size = 11}) {
    return TextStyle(
      fontFamily: bodyFont,
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: color,
    );
  }

  /// Numbers: tabular figures and no letter spacing.
  static TextStyle numeric(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    String family = bodyFont,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0,
      fontFeatures: tabular,
    );
  }

  // ---------------------------------------------------------------------------
  // Themes
  // ---------------------------------------------------------------------------
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? darkBg : lightBg;
    final surface = dark ? darkSurface : lightSurface;
    final surfaceAlt = dark ? darkSurfaceAlt : lightSurfaceAlt;
    final inkColor = dark ? darkInk : lightInk;
    final muted = dark ? darkInkMuted : lightInkMuted;
    final border = dark ? darkBorder : lightBorder;
    final primary = dark ? accentDark : accent;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: inkColor,
      onSecondary: bg,
      error: live,
      onError: Colors.white,
      surface: surface,
      onSurface: inkColor,
      surfaceContainerHighest: surfaceAlt,
      surfaceContainerHigh: surfaceAlt,
      surfaceContainer: surface,
      surfaceContainerLow: surface,
      surfaceContainerLowest: bg,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: border,
      inverseSurface: dark ? paper : ink,
      onInverseSurface: dark ? ink : paper,
    );

    TextStyle d(double size, FontWeight w, {double h = 1.15}) => TextStyle(
          fontFamily: displayFont,
          fontSize: size,
          fontWeight: w,
          height: h,
          letterSpacing: -0.4,
          color: inkColor,
        );
    TextStyle b(double size, FontWeight w, {Color? c, double h = 1.45}) =>
        TextStyle(
          fontFamily: bodyFont,
          fontSize: size,
          fontWeight: w,
          height: h,
          color: c ?? inkColor,
        );

    final textTheme = TextTheme(
      displayLarge: d(36, FontWeight.w700),
      displayMedium: d(28, FontWeight.w700),
      displaySmall: d(24, FontWeight.w700),
      headlineLarge: d(22, FontWeight.w700),
      headlineMedium: d(20, FontWeight.w700, h: 1.2),
      headlineSmall: d(18, FontWeight.w700, h: 1.22),
      titleLarge: d(18, FontWeight.w700, h: 1.25),
      titleMedium: b(15, FontWeight.w600, h: 1.35),
      titleSmall: b(13.5, FontWeight.w600, h: 1.35),
      bodyLarge: b(16.5, FontWeight.w400, h: 1.6),
      bodyMedium: b(14.5, FontWeight.w400, c: muted, h: 1.55),
      bodySmall: b(12.5, FontWeight.w400, c: muted, h: 1.45),
      labelLarge: b(14, FontWeight.w600, h: 1.2),
      labelMedium: b(12, FontWeight.w600, h: 1.2),
      labelSmall: b(11, FontWeight.w600, c: muted, h: 1.2),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: bodyFont,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
    );

    final shape12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: inkColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: d(18, FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 24),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: inkColor,
        side: BorderSide(color: border),
        labelStyle: b(13, FontWeight.w600),
        secondaryLabelStyle: b(13, FontWeight.w600, c: bg),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: b(14.5, FontWeight.w400, c: muted),
        labelStyle: b(14.5, FontWeight.w500, c: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: live),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: live, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: inkColor,
          foregroundColor: bg,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: shape12,
          textStyle: b(15, FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: shape12,
          textStyle: b(15, FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: inkColor,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: border, width: 1.2),
          shape: shape12,
          textStyle: b(15, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
          textStyle: b(14, FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: primary.withValues(alpha: dark ? 0.22 : 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return b(11.5, selected ? FontWeight.w700 : FontWeight.w500,
              c: selected ? inkColor : muted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? primary : muted, size: 24);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF26262F) : ink,
        contentTextStyle: b(14, FontWeight.w500, c: paper),
        actionTextColor: primary,
        shape: shape12,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) && !s.contains(WidgetState.disabled)
                ? Colors.white
                : null),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (!s.contains(WidgetState.selected)) return null;
          return s.contains(WidgetState.disabled)
              ? primary.withValues(alpha: 0.28)
              : primary;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        minVerticalPadding: 10,
        titleTextStyle: b(15, FontWeight.w600),
        subtitleTextStyle: b(13, FontWeight.w400, c: muted),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
