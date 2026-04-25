import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/data/preset/color_matcher.dart';
import 'package:cutmaster/data/preset/preset_seeds.dart';

void main() {
  test('exact match returns preset id', () {
    final m = ColorMatcher(seedColorPresets);
    expect(m.match(0xFFEF4444), 'cp_red'); // 빨강 정확 매칭
  });

  test('near match returns nearest by RGB distance', () {
    final m = ColorMatcher(seedColorPresets);
    // 빨강(0xFFEF4444) 근처 — distance < threshold면 cp_red 반환
    expect(m.match(0xFFEE4343), 'cp_red');
  });

  test('far color returns null (caller can auto-create)', () {
    final m = ColorMatcher(seedColorPresets);
    // 시드와 모두 멀리 떨어진 색
    expect(m.match(0xFF7B7B00), isNull);
  });
}
