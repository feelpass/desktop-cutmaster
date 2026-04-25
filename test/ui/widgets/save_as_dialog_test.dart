import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/ui/widgets/save_as_dialog.dart';

void main() {
  testWidgets('returns the trimmed name when 저장 is tapped', (t) async {
    String? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showSaveAsDialog(ctx, initialName: '책장');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '  책상  ');
    await t.tap(find.widgetWithText(FilledButton, '저장'));
    await t.pumpAndSettle();
    expect(result, '책상');
  });

  testWidgets('returns null when 취소 is tapped', (t) async {
    String? result = 'init';
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showSaveAsDialog(ctx, initialName: '책장');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('disables 저장 button when input is empty', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showSaveAsDialog(ctx, initialName: ''),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final saveBtn = find.widgetWithText(FilledButton, '저장');
    final widget = t.widget<FilledButton>(saveBtn);
    expect(widget.onPressed, isNull);
  });

  testWidgets('forbidden characters are filtered', (t) async {
    String? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showSaveAsDialog(ctx, initialName: '');
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), r'a/b\c:d*e?f"g<h>i|j');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, '저장'));
    await t.pumpAndSettle();
    expect(result, 'abcdefghij');
  });
}
