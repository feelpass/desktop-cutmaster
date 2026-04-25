import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cutmaster/main.dart' as app;
import 'package:cutmaster/ui/widgets/tab_item.dart';

/// Multi-tab E2E flow.
///
/// 시나리오:
/// 1. 앱 실행 → 최소 1개의 탭(Untitled)이 보임
/// 2. + 버튼 → "새 프로젝트" → 탭 1개 추가
/// 3. 새로 추가된 탭의 X 버튼 → 탭 1개 감소
/// 4. Cmd+Shift+T → 닫혔던 탭 재오픈 (탭 1개 다시 증가)
///
/// NOTE: 데스크톱 dev 머신에서 실제 워크스페이스를 망가뜨리지 않도록
/// setUp에서 DB/파일 삭제는 하지 않는다. 시작 시점의 탭 개수를 기준으로
/// 상대적 변화(+1, -1, +1)를 검증한다.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('multi-tab: open → +new → close → reopen', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final initial = tester.widgetList(find.byType(TabItem)).length;
    expect(initial, greaterThanOrEqualTo(1));

    // + 버튼 → 메뉴 → "새 프로젝트"
    await tester.tap(find.byKey(const ValueKey('plus-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 프로젝트'));
    await tester.pumpAndSettle();
    expect(tester.widgetList(find.byType(TabItem)).length, initial + 1);

    // 가장 마지막(방금 추가된 활성) 탭의 X 버튼으로 닫기
    final closeButtons = find.byKey(const ValueKey('tab-close'));
    await tester.tap(closeButtons.last);
    await tester.pumpAndSettle();
    expect(tester.widgetList(find.byType(TabItem)).length, initial);

    // Cmd+Shift+T → 재오픈
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(tester.widgetList(find.byType(TabItem)).length, initial + 1);
  });
}
