import 'package:flutter/material.dart';

/// 색상 팔레트 종류. UI에서 부품과 자재를 시각적으로 구분.
enum ColorPalette {
  /// 부품 — vivid 색상, "주인공" 느낌.
  part,

  /// 자재 — 목재/재질 톤, "무대 배경" 느낌.
  stock,
}

class NamedColor {
  final String name;
  final Color color;
  const NamedColor(this.name, this.color);
}

/// 부품 팔레트 (12개) — 흰 배경에서 가독성 좋고 서로 잘 구분됨.
const partColorPresets = <NamedColor>[
  NamedColor('빨강', Color(0xFFEF4444)),
  NamedColor('주황', Color(0xFFF97316)),
  NamedColor('황색', Color(0xFFEAB308)),
  NamedColor('연두', Color(0xFF84CC16)),
  NamedColor('초록', Color(0xFF16A34A)),
  NamedColor('청록', Color(0xFF14B8A6)),
  NamedColor('하늘', Color(0xFF0EA5E9)),
  NamedColor('남색', Color(0xFF3B82F6)),
  NamedColor('보라', Color(0xFF8B5CF6)),
  NamedColor('자홍', Color(0xFFD946EF)),
  NamedColor('분홍', Color(0xFFEC4899)),
  NamedColor('진홍', Color(0xFFBE123C)),
];

/// 자재 팔레트 (12개) — 목재/재질 톤. 부품과 의도적으로 구분되는 무채/저채도 색.
const stockColorPresets = <NamedColor>[
  NamedColor('자작', Color(0xFFFAF1DC)),
  NamedColor('단풍', Color(0xFFE8D2A6)),
  NamedColor('베이지', Color(0xFFD4B896)),
  NamedColor('솔송', Color(0xFFC9A876)),
  NamedColor('적참', Color(0xFFB8865C)),
  NamedColor('호두', Color(0xFF8B6240)),
  NamedColor('흑단', Color(0xFF3D2A1E)),
  NamedColor('백색멜라민', Color(0xFFF7F7F2)),
  NamedColor('연회색', Color(0xFFD4D4D4)),
  NamedColor('회색MDF', Color(0xFFA8A29E)),
  NamedColor('진회색', Color(0xFF6B6B6B)),
  NamedColor('검정멜라민', Color(0xFF262626)),
];

List<NamedColor> presetsFor(ColorPalette palette) =>
    palette == ColorPalette.part ? partColorPresets : stockColorPresets;

/// ID 해시 기반 deterministic auto 색상 — 팔레트별로 다른 분포.
/// 부품: golden angle hue 분포 + 고채도. 자재: 목재 톤 hue range + 저채도.
Color autoColorFor(String id, ColorPalette palette) {
  final hash = id.hashCode & 0x7FFFFFFF;
  if (palette == ColorPalette.part) {
    final hue = (hash * 137.508) % 360;
    return HSLColor.fromAHSL(1, hue, 0.65, 0.55).toColor();
  } else {
    // 목재 톤: hue 20-50 (warm) 또는 0 (gray) range, 저채도, 명도 다양
    final variant = hash % 100;
    if (variant < 70) {
      // 목재 톤 (warm browns/tans)
      final hue = 20 + (hash % 30).toDouble();
      final lightness = 0.4 + ((hash >> 5) % 50) / 100; // 0.4-0.9
      return HSLColor.fromAHSL(1, hue, 0.25, lightness).toColor();
    } else {
      // 무채색 (gray scale)
      final lightness = 0.3 + ((hash >> 3) % 60) / 100; // 0.3-0.9
      return HSLColor.fromAHSL(1, 0, 0, lightness).toColor();
    }
  }
}

/// 표시 색상 결정. user 명시 색 우선, 없으면 auto.
Color resolveColor(String id, int? colorArgb, ColorPalette palette) {
  if (colorArgb != null) return Color(colorArgb);
  return autoColorFor(id, palette);
}

String? presetNameOf(int argb, ColorPalette palette) {
  for (final p in presetsFor(palette)) {
    if (p.color.toARGB32() == argb) return p.name;
  }
  return null;
}
