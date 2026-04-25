import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;
import 'package:cutmaster/l10n/app_localizations.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/widgets/editable_dimension_table.dart';
import 'package:cutmaster/ui/widgets/qty_stepper.dart';

class _FakeRepo extends PresetRepository {
  _FakeRepo() : super(filePath: '/dev/null/x');
  @override
  Future<PresetState> load() async => PresetState.seeded;
  @override
  Future<void> save(PresetState s) async {}
}

Widget _wrap({
  required PresetsNotifier notifier,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [presetsProvider.overrideWith((_) => notifier)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ko'),
      home: Scaffold(body: child),
    ),
  );
}

Future<PresetsNotifier> _newNotifier() async {
  final n = PresetsNotifier(_FakeRepo());
  await n.load();
  return n;
}

void main() {
  testWidgets('row shows QtyStepper with current qty', (tester) async {
    final notifier = await _newNotifier();
    var rows = const [
      EditableRow(
        id: 'r1',
        length: 600,
        width: 300,
        qty: 3,
        label: '',
      ),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: StatefulBuilder(builder: (ctx, setState) {
        return EditableDimensionTable(
          rows: rows,
          onChanged: (next) => setState(() => rows = next),
          newId: () => 'new',
        );
      }),
    ));

    expect(find.byType(QtyStepper), findsOneWidget);
    // QtyStepper의 내부 TextField가 '3'을 보여야 함.
    final tf = tester.widget<TextField>(
      find.descendant(of: find.byType(QtyStepper), matching: find.byType(TextField)),
    );
    expect(tf.controller!.text, '3');
  });

  testWidgets('meta line shows preset color name when colorPresetId set',
      (tester) async {
    final notifier = await _newNotifier();
    var rows = const [
      EditableRow(
        id: 'r1',
        length: 600,
        width: 300,
        qty: 1,
        label: '',
        colorPresetId: 'cp_red',
      ),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: StatefulBuilder(builder: (ctx, setState) {
        return EditableDimensionTable(
          rows: rows,
          onChanged: (next) => setState(() => rows = next),
          newId: () => 'new',
        );
      }),
    ));

    expect(find.text('빨강'), findsOneWidget);
  });

  testWidgets('meta line shows "자동" when colorPresetId null', (tester) async {
    final notifier = await _newNotifier();
    var rows = const [
      EditableRow(
        id: 'r1',
        length: 600,
        width: 300,
        qty: 1,
        label: '',
        colorPresetId: null,
      ),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: StatefulBuilder(builder: (ctx, setState) {
        return EditableDimensionTable(
          rows: rows,
          onChanged: (next) => setState(() => rows = next),
          newId: () => 'new',
        );
      }),
    ));

    expect(find.text('자동'), findsOneWidget);
  });

  testWidgets('meta line label inline edit on tap', (tester) async {
    final notifier = await _newNotifier();
    var rows = const [
      EditableRow(
        id: 'r1',
        length: 600,
        width: 300,
        qty: 1,
        label: '',
      ),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: StatefulBuilder(builder: (ctx, setState) {
        return EditableDimensionTable(
          rows: rows,
          onChanged: (next) => setState(() => rows = next),
          newId: () => 'new',
        );
      }),
    ));

    // 빈 라벨 placeholder 탭 → TextField 등장.
    final placeholder = find.text('라벨 추가...');
    expect(placeholder, findsOneWidget);

    // 탭 전: 다이멘션 셀 (length/width) 의 TextField 두 개.
    final beforeTfs = find.byType(TextField);
    final beforeCount = tester.widgetList<TextField>(beforeTfs).length;

    await tester.tap(placeholder);
    await tester.pumpAndSettle();

    // 탭 후: TextField 추가됨 (라벨 인라인 편집).
    final afterTfs = find.byType(TextField);
    final afterCount = tester.widgetList<TextField>(afterTfs).length;
    expect(afterCount, greaterThan(beforeCount));
  });

  testWidgets('meta line shows grain icon when grainDirection != none',
      (tester) async {
    final notifier = await _newNotifier();
    var rows = const [
      EditableRow(
        id: 'r1',
        length: 600,
        width: 300,
        qty: 1,
        label: '',
        grainDirection: GrainDirection.lengthwise,
      ),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: StatefulBuilder(builder: (ctx, setState) {
        return EditableDimensionTable(
          rows: rows,
          onChanged: (next) => setState(() => rows = next),
          newId: () => 'new',
        );
      }),
    ));

    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
  });
}
