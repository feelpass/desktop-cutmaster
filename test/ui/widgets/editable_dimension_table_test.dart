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

  testWidgets('meta line shows label as read-only text', (tester) async {
    final notifier = await _newNotifier();
    final rowsEmpty = const [
      EditableRow(id: 'r1', length: 600, width: 300, qty: 1, label: ''),
    ];
    await tester.pumpWidget(_wrap(
      notifier: notifier,
      child: EditableDimensionTable(
        rows: rowsEmpty,
        onChanged: (_) {},
        newId: () => 'new',
      ),
    ));

    // 빈 라벨은 placeholder em-dash로 표시되고 편집 TextField는 없다.
    expect(find.text('—'), findsOneWidget);

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
          newId: () => 'x',
        );
      }),
    ));
    expect(find.byIcon(Icons.drag_indicator), findsNothing);
  });

  // Note: actually driving a reorder via tester.drag/timedDrag against
  // ReorderableListView's drag handle is fragile in widget tests
  // (it depends on long-press timers + scroll behavior). The list-mutation
  // logic itself is trivial (Flutter's documented oldIndex/newIndex quirk
  // adjusted in `_handleReorder`). End-to-end coverage will land at the
  // integration test level.

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
