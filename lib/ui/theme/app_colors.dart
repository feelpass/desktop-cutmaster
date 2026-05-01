import 'package:flutter/material.dart';

/// 시각 토큰 — Linear-inspired (DESIGN.md 참조).
///
/// 두 종류로 나뉜다:
/// 1) **불변 토큰** (`AppColors`의 static const): brand accent, status, 자재 데이터 등
///    — 라이트/다크 모드와 무관하게 동일한 의미.
/// 2) **테마 가변 토큰** (`AppPalette` ThemeExtension): 표면, 보더, 텍스트 톤 —
///    라이트/다크에 따라 값이 달라진다. 위젯에서 `context.colors.X`로 접근.
class AppColors {
  AppColors._();

  // ─── 불변 — chromatic accent (DESIGN.md §2 Brand & Accent) ───
  static const primary = Color(0xFF5E6AD2); // Brand Indigo
  static const accent = Color(0xFF7170FF); // Accent Violet
  static const accentHover = Color(0xFF828FFF);

  // ─── 불변 — status ───
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFEAB308);
  static const danger = Color(0xFFEF4444);

  // ─── 라이트 모드 호환 별칭 (BuildContext 없는 코드용) ───
  // 새 코드는 `context.colors.X`를 쓸 것. 이 별칭은 sheet_painter 등 painter나
  // 정적 데이터를 위해 light 모드 디폴트를 노출.
  static const header = Color(0xFFFFFFFF);
  static const textOnHeader = Color(0xFF08090A);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF7F8F8);
  static const surfaceAlt = Color(0xFFF3F4F5);
  static const sectionHeaderBg = Color(0xFFF3F4F5);
  static const border = Color(0xFFE6E6E6);
  static const borderStrong = Color(0xFFD0D6E0);
  static const textPrimary = Color(0xFF08090A);
  static const textSecondary = Color(0xFF62666D);
  static const textMuted = Color(0xFF8A8F98);
  static const tableHeaderText = Color(0xFF62666D);
}

/// 테마 가변 토큰 — `Theme.of(context).extension<AppPalette>()`로 접근.
/// 위젯에서는 `context.colors.X` getter를 권장.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.header,
    required this.textOnHeader,
    required this.headerBorder,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.sectionHeaderBg,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.tableHeaderText,
  });

  // 시그니처 헤더
  final Color header;
  final Color textOnHeader;
  final Color headerBorder;

  // Luminance stacking (DESIGN.md §6)
  final Color background;     // 페이지 배경 (가장 lifted/active)
  final Color surface;        // 좌측 패널 등 입력 zone
  final Color surfaceAlt;     // 카드/입력 fill (recessed)
  final Color sectionHeaderBg;

  // Borders
  final Color border;
  final Color borderStrong;

  // Text 4단 위계
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color tableHeaderText;

  /// Linear 라이트 모드 — Light Background `#f7f8f8`, Pure White cards 위로 떠 있음.
  static const light = AppPalette(
    header: Color(0xFFFFFFFF),
    textOnHeader: Color(0xFF08090A),
    headerBorder: Color(0xFFE6E6E6),
    background: Color(0xFFFFFFFF), // 메인 페이지/카드: pure white
    surface: Color(0xFFF7F8F8), // 좌측 패널: Light Background tint
    surfaceAlt: Color(0xFFF3F4F5), // 입력 fill, 더 깊은 표면
    sectionHeaderBg: Color(0xFFECECEE),
    border: Color(0xFFE6E6E6),
    borderStrong: Color(0xFFD0D6E0),
    textPrimary: Color(0xFF08090A),
    textSecondary: Color(0xFF62666D),
    textMuted: Color(0xFF8A8F98),
    tableHeaderText: Color(0xFF62666D),
  );

  /// Linear 다크 모드 — `#08090a` marketing black, `#0f1011` panel,
  /// `#191a1b` elevated surface.
  static const dark = AppPalette(
    header: Color(0xFF0F1011), // Panel Dark
    textOnHeader: Color(0xFFF7F8F8),
    headerBorder: Color(0xFF23252A), // semi-transparent 대신 solid
    background: Color(0xFF08090A), // 페이지/캔버스: Marketing Black
    surface: Color(0xFF0F1011), // 좌측 패널
    surfaceAlt: Color(0xFF191A1B), // 입력 fill, elevated
    sectionHeaderBg: Color(0xFF18191A),
    border: Color(0xFF23252A),
    borderStrong: Color(0xFF34343A),
    textPrimary: Color(0xFFF7F8F8),
    textSecondary: Color(0xFFD0D6E0),
    textMuted: Color(0xFF8A8F98),
    tableHeaderText: Color(0xFF8A8F98),
  );

  @override
  AppPalette copyWith({
    Color? header,
    Color? textOnHeader,
    Color? headerBorder,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? sectionHeaderBg,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? tableHeaderText,
  }) =>
      AppPalette(
        header: header ?? this.header,
        textOnHeader: textOnHeader ?? this.textOnHeader,
        headerBorder: headerBorder ?? this.headerBorder,
        background: background ?? this.background,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        sectionHeaderBg: sectionHeaderBg ?? this.sectionHeaderBg,
        border: border ?? this.border,
        borderStrong: borderStrong ?? this.borderStrong,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        tableHeaderText: tableHeaderText ?? this.tableHeaderText,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      header: Color.lerp(header, other.header, t)!,
      textOnHeader: Color.lerp(textOnHeader, other.textOnHeader, t)!,
      headerBorder: Color.lerp(headerBorder, other.headerBorder, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      sectionHeaderBg: Color.lerp(sectionHeaderBg, other.sectionHeaderBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      tableHeaderText: Color.lerp(tableHeaderText, other.tableHeaderText, t)!,
    );
  }
}

/// 위젯에서 `context.colors.surface` 형태로 접근.
/// 테마에 AppPalette 확장이 없으면 light 디폴트로 fallback (테스트 안정성).
extension AppPaletteContext on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
