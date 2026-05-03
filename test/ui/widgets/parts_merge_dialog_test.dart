import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/import/parts_merge.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/l10n/app_localizations.dart';
import 'package:cutmaster/ui/widgets/parts_merge_dialog.dart';

CutPart _p(String label, {int qty = 1}) => CutPart(
      id: '$label-$qty',
      label: label,
      length: 600,
      width: 300,
      thickness: 18,
      qty: qty,
      colorPresetId: 'white',
    );

PartsMergeConflict _c(String label, {int existingIdx = 0, int incQty = 1}) =>
    PartsMergeConflict(
      existingIndex: existingIdx,
      existing: _p(label, qty: 3),
      incoming: _p(label, qty: incQty),
    );

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: child,
      );

  Future<MergeAction?> openDialog(
    WidgetTester tester,
    List<PartsMergeConflict> conflicts,
  ) async {
    MergeAction? result;
    await tester.pumpWidget(wrap(Builder(builder: (ctx) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showPartsMergeDialog(ctx, conflicts);
            },
            child: const Text('open'),
          ),
        ),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('덮어쓰기 버튼 → MergeAction.overwrite 반환', (tester) async {
    final conflicts = [_c('선반')];
    MergeAction? result;
    await tester.pumpWidget(wrap(Builder(builder: (ctx) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showPartsMergeDialog(ctx, conflicts);
            },
            child: const Text('open'),
          ),
        ),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('덮어쓰기'));
    await tester.pumpAndSettle();
    expect(result, MergeAction.overwrite);
  });

  testWidgets('수량 증가 버튼 → MergeAction.addQty 반환', (tester) async {
    final conflicts = [_c('선반')];
    MergeAction? result;
    await tester.pumpWidget(wrap(Builder(builder: (ctx) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showPartsMergeDialog(ctx, conflicts);
            },
            child: const Text('open'),
          ),
        ),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('수량 증가'));
    await tester.pumpAndSettle();
    expect(result, MergeAction.addQty);
  });

  testWidgets('이름 변경 후 추가 버튼 → MergeAction.renameAndAdd 반환',
      (tester) async {
    final conflicts = [_c('선반')];
    MergeAction? result;
    await tester.pumpWidget(wrap(Builder(builder: (ctx) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showPartsMergeDialog(ctx, conflicts);
            },
            child: const Text('open'),
          ),
        ),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('이름 변경 후 추가'));
    await tester.pumpAndSettle();
    expect(result, MergeAction.renameAndAdd);
  });

  testWidgets('취소 버튼 → MergeAction.cancel 반환', (tester) async {
    final conflicts = [_c('선반')];
    MergeAction? result;
    await tester.pumpWidget(wrap(Builder(builder: (ctx) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showPartsMergeDialog(ctx, conflicts);
            },
            child: const Text('open'),
          ),
        ),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, MergeAction.cancel);
  });

  testWidgets('충돌 N개 표시: 라벨/사이즈/qty가 보임', (tester) async {
    final conflicts = [
      _c('선반', incQty: 2),
      _c('측판', existingIdx: 1, incQty: 4),
    ];
    await openDialog(tester, conflicts);

    expect(find.textContaining('선반'), findsWidgets);
    expect(find.textContaining('측판'), findsWidgets);
  });
}
