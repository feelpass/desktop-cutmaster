import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/ui/widgets/qty_stepper.dart';

void main() {
  testWidgets('+ button increments by 1', (tester) async {
    int v = 3;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      StatefulBuilder(builder: (ctx, setState) => QtyStepper(
        value: v, onChanged: (n) => setState(() => v = n),
      )))));
    await tester.tap(find.byTooltip('증가'));
    await tester.pumpAndSettle();
    expect(v, 4);
  });

  testWidgets('- below 1 clamps to 1', (tester) async {
    int v = 1;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      StatefulBuilder(builder: (ctx, setState) => QtyStepper(
        value: v, onChanged: (n) => setState(() => v = n),
      )))));
    await tester.tap(find.byTooltip('감소'));
    await tester.pumpAndSettle();
    expect(v, 1);
  });

  testWidgets('typing 0 clamps to 1 on commit', (tester) async {
    int v = 5;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      StatefulBuilder(builder: (ctx, setState) => QtyStepper(
        value: v, onChanged: (n) => setState(() => v = n),
      )))));
    await tester.enterText(find.byType(TextField), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(v, 1);
  });
}
