import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/widgets/color_preset_management_dialog.dart';

class _FakeRepo extends PresetRepository {
  _FakeRepo() : super(filePath: '/dev/null/x');
  @override
  Future<PresetState> load() async => PresetState.seeded;
  @override
  Future<void> save(PresetState s) async {}
}

void main() {
  testWidgets('shows list of seed colors', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: const MaterialApp(home: ColorPresetManagementDialog()),
    ));
    expect(find.text('호두'), findsOneWidget);
    expect(find.text('빨강'), findsOneWidget);
  });

  testWidgets('add button creates new color and selects it', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    final initialLen = notifier.state.colors.length;
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: const MaterialApp(home: ColorPresetManagementDialog()),
    ));
    await tester.tap(find.byTooltip('추가'));
    await tester.pumpAndSettle();
    expect(notifier.state.colors.length, initialLen + 1);
  });
}
