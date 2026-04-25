import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/widgets/preset_dialog.dart';
import 'package:cutmaster/ui/widgets/preset_management_dialog.dart';

class _FakeRepo extends PresetRepository {
  _FakeRepo() : super(filePath: '/dev/null/x');
  @override
  Future<PresetState> load() async => PresetState.seeded;
  @override
  Future<void> save(PresetState s) async {}
}

/// 다이얼로그를 띄울 트리거 버튼이 있는 테스트 호스트.
Widget _host({
  required PresetsNotifier notifier,
  required PresetKind kind,
  ValueChanged<dynamic>? onResult,
}) {
  return ProviderScope(
    overrides: [presetsProvider.overrideWith((_) => notifier)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final r = await showPresetDialog(ctx, kind);
                if (onResult != null) onResult(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('stock kind shows seed presets', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    await tester.pumpWidget(_host(notifier: notifier, kind: PresetKind.stock));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('자재 프리셋 선택'), findsOneWidget);
    expect(find.text('12T 합판'), findsWidgets);
  });

  testWidgets('part kind empty state shows placeholder', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    expect(notifier.state.parts, isEmpty);

    await tester.pumpWidget(_host(notifier: notifier, kind: PresetKind.part));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('부품 프리셋 선택'), findsOneWidget);
    expect(
      find.text('아직 등록된 프리셋이 없습니다. 아래 "프리셋 관리..."로 추가하세요.'),
      findsOneWidget,
    );
  });

  testWidgets('"프리셋 관리..." button opens management dialog without closing picker',
      (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    await tester.pumpWidget(_host(notifier: notifier, kind: PresetKind.stock));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Picker is up.
    expect(find.text('자재 프리셋 선택'), findsOneWidget);

    // Tap '프리셋 관리...'
    await tester.tap(find.text('프리셋 관리...'));
    await tester.pumpAndSettle();

    // Both dialogs visible: picker is still mounted, management is on top.
    expect(find.text('자재 프리셋 선택'), findsOneWidget);
    expect(find.text('자재 프리셋 관리'), findsOneWidget);
  });

  testWidgets('selecting a stock preset returns a StockSheet with qty=1 and fresh id',
      (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    dynamic result;
    await tester.pumpWidget(_host(
      notifier: notifier,
      kind: PresetKind.stock,
      onResult: (r) => result = r,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap first row in list.
    final firstRow = notifier.state.stocks.first;
    await tester.tap(find.text(firstRow.label).first);
    await tester.pumpAndSettle();

    expect(result, isA<StockSheet>());
    final ss = result as StockSheet;
    expect(ss.qty, 1);
    expect(ss.id.startsWith('s_'), isTrue);
    expect(ss.length, firstRow.length);
    expect(ss.width, firstRow.width);
    expect(ss.label, firstRow.label);
    expect(ss.colorPresetId, firstRow.colorPresetId);
    expect(ss.grainDirection, firstRow.grainDirection);
  });

  testWidgets('selecting a part preset returns a CutPart with qty=1 and fresh id',
      (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    // Seed empty parts list — add one for this test.
    await notifier.addPartPreset(const DimensionPreset(
      id: 'pp_test',
      length: 600,
      width: 300,
      label: '테스트 부품',
      colorPresetId: null,
      grainDirection: GrainDirection.none,
    ));
    dynamic result;
    await tester.pumpWidget(_host(
      notifier: notifier,
      kind: PresetKind.part,
      onResult: (r) => result = r,
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('테스트 부품'));
    await tester.pumpAndSettle();

    expect(result, isA<CutPart>());
    final cp = result as CutPart;
    expect(cp.qty, 1);
    expect(cp.id.startsWith('p_'), isTrue);
    expect(cp.length, 600);
    expect(cp.width, 300);
    expect(cp.label, '테스트 부품');
  });
}
