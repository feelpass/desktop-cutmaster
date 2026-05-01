import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Linear-inspired 타이포 위계 (DESIGN.md 섹션 3 참조).
///
/// 색은 라이트/다크 모드에 따라 달라야 하므로 여기서는 가능한 한 **색을 비워둔다**.
/// Flutter의 `DefaultTextStyle` 또는 `Text` 위젯이 `Theme.of(ctx).textTheme`에서
/// 색을 상속받도록 하거나, 사용처에서 `.copyWith(color: context.colors.X)`로
/// 명시적으로 주입한다.
///
/// Linear weight 510/590 → Pretendard 정수 weight 500/600 매핑.
class AppTextStyles {
  AppTextStyles._();

  // 본문 (Body Medium) — 색은 textTheme.bodyMedium에서 상속.
  static const body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.13,
    height: 1.5,
  );

  // 표 셀 — body와 동일하지만 의도가 다르므로 별칭 유지.
  static const tableCell = body;

  // 표 헤더 (Caption) — 색은 위젯에서 `.copyWith(color: context.colors.tableHeaderText)`.
  static const tableHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.12,
    height: 1.4,
  );

  // 좌측 패널 섹션 헤더 (Caption Large)
  static const sectionHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.13,
    height: 1.5,
  );

  // 결과 패널의 큰 효율 숫자 (Display) — primary 색은 항상 indigo (불변).
  static const efficiencyNumber = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    letterSpacing: -0.704,
    height: 1.13,
  );

  // 빈 상태 / 플레이스홀더 (Small) — textMuted 적용은 사용처에서.
  static const emptyHint = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.165,
    height: 1.6,
  );

  // 라벨/버튼 (Label)
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  // 헤더 타이틀 — 헤더 위 텍스트 색은 테마 가변이므로 함수로 노출.
  static TextStyle topBarTitle(BuildContext context) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.colors.textOnHeader,
        letterSpacing: -0.13,
        height: 1.4,
      );
}
