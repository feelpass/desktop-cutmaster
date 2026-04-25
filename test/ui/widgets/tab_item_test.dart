import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/ui/widgets/tab_item.dart';

void main() {
  testWidgets('shows display name and dirty dot when isDirty', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true,
          isDirty: true,
          isUntitled: false,
          onTap: () {},
          onClose: () {},
          onRenameSubmit: (_) {},
        ),
      ),
    ));
    expect(find.text('책장'), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-dirty-dot')), findsOneWidget);
  });

  testWidgets('tapping X calls onClose', (t) async {
    var closed = false;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true,
          isDirty: false,
          isUntitled: false,
          onTap: () {},
          onClose: () => closed = true,
          onRenameSubmit: (_) {},
        ),
      ),
    ));
    await t.tap(find.byKey(const ValueKey('tab-close')));
    expect(closed, true);
  });

  testWidgets('double tap turns into TextField, Enter submits new name', (t) async {
    String? submitted;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true,
          isDirty: false,
          isUntitled: false,
          onTap: () {},
          onClose: () {},
          onRenameSubmit: (v) => submitted = v,
        ),
      ),
    ));
    await t.tap(find.text('책장'));
    await t.pump(kDoubleTapMinTime + const Duration(milliseconds: 5));
    await t.tap(find.text('책장'));
    await t.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await t.enterText(find.byType(TextField), '책상');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(submitted, '책상');
  });

  testWidgets('Esc cancels rename', (t) async {
    String? submitted;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true,
          isDirty: false,
          isUntitled: false,
          onTap: () {},
          onClose: () {},
          onRenameSubmit: (v) => submitted = v,
        ),
      ),
    ));
    await t.tap(find.text('책장'));
    await t.pump(kDoubleTapMinTime + const Duration(milliseconds: 5));
    await t.tap(find.text('책장'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '책상');
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(submitted, isNull);
  });

  testWidgets('empty input does not submit', (t) async {
    String? submitted;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true, isDirty: false, isUntitled: false,
          onTap: () {}, onClose: () {},
          onRenameSubmit: (v) => submitted = v,
        ),
      ),
    ));
    await t.tap(find.text('책장'));
    await t.pump(kDoubleTapMinTime + const Duration(milliseconds: 5));
    await t.tap(find.text('책장'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), '   ');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(submitted, isNull);
  });

  testWidgets('forbidden characters are filtered from input', (t) async {
    String? submitted;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true, isDirty: false, isUntitled: false,
          onTap: () {}, onClose: () {},
          onRenameSubmit: (v) => submitted = v,
        ),
      ),
    ));
    await t.tap(find.text('책장'));
    await t.pump(kDoubleTapMinTime + const Duration(milliseconds: 5));
    await t.tap(find.text('책장'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), r'a/b\c:d*e?f"g<h>i|j');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(submitted, 'abcdefghij');
  });

  testWidgets('edit mode hides dirty dot and close button', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TabItem(
          displayName: '책장',
          isActive: true, isDirty: true, isUntitled: true,
          onTap: () {}, onClose: () {},
          onRenameSubmit: (_) {},
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('tab-dirty-dot')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-close')), findsOneWidget);

    await t.tap(find.text('책장'));
    await t.pump(kDoubleTapMinTime + const Duration(milliseconds: 5));
    await t.tap(find.text('책장'));
    await t.pumpAndSettle();

    expect(find.byKey(const ValueKey('tab-dirty-dot')), findsNothing);
    expect(find.byKey(const ValueKey('tab-close')), findsNothing);
  });

  testWidgets('external displayName change exits edit mode', (t) async {
    String? submitted;
    final outerKey = GlobalKey();
    var name = '책장';
    late StateSetter rebuild;

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          key: outerKey,
          builder: (context, setState) {
            rebuild = setState;
            return TabItem(
              displayName: name,
              isActive: true, isDirty: false, isUntitled: false,
              onTap: () {}, onClose: () {},
              onRenameSubmit: (v) => submitted = v,
            );
          },
        ),
      ),
    ));

    await t.tap(find.text('책장'));
    await t.pump(kDoubleTapMinTime + const Duration(milliseconds: 5));
    await t.tap(find.text('책장'));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    rebuild(() => name = '책상');
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('책상'), findsOneWidget);
    expect(submitted, isNull); // 외부 변경은 콜백 없음
  });
}
