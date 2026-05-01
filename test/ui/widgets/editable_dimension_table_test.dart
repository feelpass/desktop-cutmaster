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

void _setWideViewport(WidgetTester tester) {
  // 행 칼럼 합계 ~880px — 기본 800 viewport는 좁아 RenderFlex overflow 발생.
  tester.view.physicalSize = const Size(1400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets('row shows QtyStepper with current qty', (tester) async {
    _setWideViewport(tester);
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
    final tf = tester.widget<TextField>(
      find.descendant(
          of: find.byType(QtyStepper), matching: find.byType(TextField)),
    );
    expect(tf.controller!.text, '3');
  });

  testWidgets('material badge shows preset color name + thickness',
      (tester) async {
    _setWideViewport(tester);
    final notifier = await _newNotifier();
    var rows = const [
      EditableRow(
        id: 'r1',
        length: 600,
        width: 300,
        qty: 1,
        label: '',
        colorPresetId: 'cp_red',
        thickness: 18,
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

    expect(find.text('빨강_18T'), findsOneWidget);
  });

  testWidgets('material badge shows "자동" when colorPresetId null',
      (tester) async {
    _setWideViewport(tester);
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

  testWidgets('row shows label inline next to color swatch (when present)',
      (tester) async {
    _setWideViewport(tester);
    final notifier = await _newNotifier();
    final rowsLabeled = const [
      EditableRow(id: 'r1', length: 600, width: 300, qty: 1, label: '12T 합판'),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: EditableDimensionTable(
        rows: rowsLabeled,
        onChanged: (_) {},
        newId: () => 'new',
      ),
    ));
    expect(find.text('12T 합판'), findsOneWidget);
  });

  testWidgets('drag handle visible when onReorder provided', (tester) async {
    _setWideViewport(tester);
    final notifier = await _newNotifier();
    var rows = const [
      EditableRow(
        id: 'r1',
        length: 100,
        width: 50,
        qty: 1,
        label: 'a',
        colorPresetId: null,
        grainDirection: GrainDirection.none,
      ),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: StatefulBuilder(builder: (ctx, setState) {
        return EditableDimensionTable(
          rows: rows,
          onChanged: (next) => setState(() => rows = next),
          onReorder: (next) => setState(() => rows = next),
          newId: () => 'x',
        );
      }),
    ));
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
  });

  testWidgets('drag handle hidden when onReorder null', (tester) async {
    _setWideViewport(tester);
    final notifier = await _newNotifier();
    var rows = const [
      EditableRow(
        id: 'r1',
        length: 100,
        width: 50,
        qty: 1,
        label: 'a',
      ),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: StatefulBuilder(builder: (ctx, setState) {
        return EditableDimensionTable(
          rows: rows,
          onChanged: (next) => setState(() => rows = next),
          newId: () => 'x',
        );
      }),
    ));
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
  });

  testWidgets('row number is displayed', (tester) async {
    _setWideViewport(tester);
    final notifier = await _newNotifier();
    final rows = const [
      EditableRow(id: 'r1', length: 100, width: 50, qty: 1, label: 'a'),
      EditableRow(id: 'r2', length: 200, width: 60, qty: 2, label: 'b'),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: EditableDimensionTable(
        rows: rows,
        onChanged: (_) {},
        newId: () => 'x',
      ),
    ));
    // Header has '#', plus 2 rows have '1' and '2'.
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
  });
}
