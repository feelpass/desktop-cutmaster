import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/ui/providers/app_info_provider.dart';
import 'package:cutmaster/ui/widgets/shortcuts_cheatsheet_dialog.dart';

Widget _harness({required Widget child}) {
  return ProviderScope(
    overrides: [
      appVersionProvider.overrideWith((ref) async => '0.1.0+1'),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => showShortcutsCheatsheet(ctx),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('cheatsheet dialog shows shortcut list', (tester) async {
    await tester.pumpWidget(_harness(child: const SizedBox.shrink()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('단축키'), findsOneWidget);
    expect(find.text('새 프로젝트'), findsOneWidget);
    expect(find.text('⌘N'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    expect(find.text('⌘S'), findsOneWidget);
    expect(find.text('다른 이름으로 저장'), findsOneWidget);
    expect(find.text('⌘⇧S'), findsOneWidget);
  });

  testWidgets('cheatsheet dialog shows app version footer', (tester) async {
    await tester.pumpWidget(_harness(child: const SizedBox.shrink()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Cutmaster v0.1.0+1'), findsOneWidget);
  });

  testWidgets('close button dismisses the dialog', (tester) async {
    await tester.pumpWidget(_harness(child: const SizedBox.shrink()));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('단축키'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('단축키'), findsNothing);
  });
}
