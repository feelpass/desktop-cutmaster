import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/widgets/preset_management_dialog.dart';

class _FakeRepo extends PresetRepository {
  _FakeRepo() : super(filePath: '/dev/null/x');
  @override
  Future<PresetState> load() async => PresetState.seeded;
  @override
  Future<void> save(PresetState s) async {}
}

void main() {
  testWidgets('stock kind shows seed stock presets', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: const MaterialApp(
        home: PresetManagementDialog(kind: PresetKind.stock),
      ),
    ));
    expect(find.text('12T 합판'), findsOneWidget);
    expect(find.text('15T 합판'), findsOneWidget);
  });

  testWidgets('part kind shows empty list (seedPartPresets is empty)',
      (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: const MaterialApp(
        home: PresetManagementDialog(kind: PresetKind.part),
      ),
    ));
    // Empty list — '추가' button is the only interaction
    expect(find.byTooltip('추가'), findsOneWidget);
    expect(notifier.state.parts, isEmpty);
  });

  testWidgets('add button creates new part preset', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: const MaterialApp(
        home: PresetManagementDialog(kind: PresetKind.part),
      ),
    ));
    await tester.tap(find.byTooltip('추가'));
    await tester.pumpAndSettle();
    expect(notifier.state.parts.length, 1);
  });
}
