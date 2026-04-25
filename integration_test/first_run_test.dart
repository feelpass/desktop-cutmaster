import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cutmaster/main.dart' as app;

/// First-run E2E flow.
///
/// 시나리오:
/// 1. 앱 실행 → MainScreen에 EmptyResultPane 보임 ("자재와 부품을 입력하고...")
/// 2. 좌측 자재 섹션의 "프리셋" 버튼 클릭 → 프리셋 다이얼로그
/// 3. "2440 × 1220 (12T)" 선택 → 자재 추가됨
/// 4. 좌측 부품 섹션의 "행 추가" → 부품 1개 추가, 인라인 편집
/// 5. 상단 "▶ 계산" 클릭
/// 6. 우측 결과 영역에 효율% 표시 (% 문자 포함)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('first-run: 프리셋 자재 + 부품 1개 → 계산 → 효율 표시', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // EmptyResultPane 확인
    expect(find.textContaining('계산 버튼'), findsOneWidget);

    // 자재 섹션 → "프리셋" 버튼
    await tester.tap(find.text('프리셋'));
    await tester.pumpAndSettle();

    // 첫 프리셋 선택
    expect(find.text('2440 × 1220 (12T)'), findsOneWidget);
    await tester.tap(find.text('2440 × 1220 (12T)'));
    await tester.pumpAndSettle();

    // 부품 행 추가 (행 추가 버튼은 부품 섹션 마지막에 있음)
    final addRow = find.text('행 추가').first;
    await tester.tap(addRow);
    await tester.pumpAndSettle();

    // 계산 버튼 클릭
    final calculate = find.text('계산');
    expect(calculate, findsOneWidget);
    await tester.tap(calculate);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 결과 영역에 효율% 표시 (또는 unplaced 표시 — 둘 중 하나)
    // 빈 부품 list로는 효율 0% 표시될 가능성 — 어떤 형태든 결과 영역이 비지 않아야 함
    expect(find.textContaining('%'), findsWidgets);
  });
}
