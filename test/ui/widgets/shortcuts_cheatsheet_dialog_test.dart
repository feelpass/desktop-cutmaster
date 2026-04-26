import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/ui/widgets/shortcuts_cheatsheet_dialog.dart';

void main() {
  testWidgets('cheatsheet dialog shows shortcut list', (tester) async {
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('단축키'), findsOneWidget);
    expect(find.text('새 프로젝트'), findsOneWidget);
    expect(find.text('⌘N'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    expect(find.text('⌘S'), findsOneWidget);
  });

  testWidgets('close button dismisses the dialog', (tester) async {
    await tester.pumpWidget(MaterialApp(
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
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('단축키'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('단축키'), findsNothing);
  });
}
