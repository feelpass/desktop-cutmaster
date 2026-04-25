import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/widgets/color_picker_dialog.dart';
import 'package:cutmaster/ui/widgets/color_preset_management_dialog.dart';

class _FakeRepo extends PresetRepository {
  _FakeRepo() : super(filePath: '/dev/null/x');
  @override
  Future<PresetState> load() async => PresetState.seeded;
  @override
  Future<void> save(PresetState s) async {}
}

void main() {
  testWidgets('shows global color presets and "자동" option', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  showColorPickerDialog(ctx, currentPresetId: null),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('자동 (ID 기반)'), findsOneWidget);
    expect(find.text('빨강'), findsOneWidget);
    expect(find.text('호두'), findsOneWidget);
  });

  testWidgets('tapping a preset swatch returns ColorChoice.value(presetId)',
      (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();

    ColorChoice? captured;
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                captured = await showColorPickerDialog(
                  ctx,
                  currentPresetId: null,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('빨강'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.presetId, 'cp_red');
  });

  testWidgets('tapping "자동" returns ColorChoice.auto', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();

    ColorChoice? captured;
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                captured = await showColorPickerDialog(
                  ctx,
                  currentPresetId: 'cp_red',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('자동 (ID 기반)'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.presetId, isNull);
  });

  testWidgets('"색상 프리셋 관리..." entry opens management dialog',
      (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();

    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  showColorPickerDialog(ctx, currentPresetId: null),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // 관리 entry 클릭 → management 다이얼로그가 트리에 합류해야 함.
    expect(find.byType(ColorPresetManagementDialog), findsNothing);
    await tester.tap(find.text('색상 프리셋 관리...'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorPresetManagementDialog), findsOneWidget);
  });
}
