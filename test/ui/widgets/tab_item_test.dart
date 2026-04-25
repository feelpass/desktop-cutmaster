import 'package:flutter/material.dart';
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
}
