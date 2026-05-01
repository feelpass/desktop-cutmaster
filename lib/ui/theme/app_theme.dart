import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Linear-inspired Material 3 테마 (DESIGN.md 참조).
///
/// 반경 스케일 — DESIGN.md 섹션 5:
///   micro 2 / standard 4 / comfortable 6 / card 8 / panel 12 / pill 9999.
class AppTheme {
  AppTheme._();

  // Border radius scale (DESIGN.md §5)
  static const radiusMicro = 2.0;
  static const radiusStandard = 4.0;
  static const radiusComfortable = 6.0;
  static const radiusCard = 8.0;
  static const radiusPanel = 12.0;

  // Spacing scale (8px 베이스, DESIGN.md §5)
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        palette: AppPalette.light,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        palette: AppPalette.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      surface: palette.background,
      onSurface: palette.textPrimary,
      surfaceContainerLowest: palette.background,
      surfaceContainerLow: palette.surface,
      surfaceContainer: palette.surfaceAlt,
      surfaceContainerHigh: palette.sectionHeaderBg,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.border,
      outlineVariant: palette.borderStrong,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Pretendard',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      dividerColor: palette.border,
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      visualDensity: VisualDensity.compact,
      extensions: [palette],
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: palette.textPrimary),
        bodyMedium: TextStyle(color: palette.textPrimary),
        bodySmall: TextStyle(color: palette.textPrimary),
        labelMedium: TextStyle(color: palette.textPrimary),
        titleSmall: TextStyle(color: palette.textPrimary),
      ).apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: palette.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius:
              const BorderRadius.all(Radius.circular(radiusComfortable)),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              const BorderRadius.all(Radius.circular(radiusComfortable)),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              const BorderRadius.all(Radius.circular(radiusComfortable)),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: palette.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusComfortable),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.13,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusComfortable),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusComfortable),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.13,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusStandard),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.background,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: palette.border),
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? palette.surfaceAlt : const Color(0xFF08090A),
          borderRadius: BorderRadius.circular(radiusStandard),
          border: Border.all(color: palette.border),
        ),
        textStyle: TextStyle(
          color: isDark ? palette.textPrimary : Colors.white,
          fontSize: 12,
          letterSpacing: -0.12,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMicro + 1),
        ),
        side: BorderSide(color: palette.borderStrong),
      ),
    );
  }
}
