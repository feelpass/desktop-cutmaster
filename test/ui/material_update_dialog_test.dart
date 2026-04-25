import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/l10n/app_localizations.dart';
import 'package:cutmaster/ui/widgets/material_update_dialog.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: child,
      );

  testWidgets('자재 수정 다이얼로그: "예" 누르면 true 반환', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(Builder(builder: (ctx) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showMaterialUpdateDialog(ctx);
            },
            child: const Text('open'),
          ),
        ),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('자재가 변경되었습니다'), findsOneWidget);

    await tester.tap(find.text('예'));
    await tester.pumpAndSettle();
    expect(result, true);
  });

  testWidgets('자재 수정 다이얼로그: "아니오" 누르면 false 반환', (tester) async {
    bool? result;
    await tester.pumpWidget(wrap(Builder(builder: (ctx) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await showMaterialUpdateDialog(ctx);
            },
            child: const Text('open'),
          ),
        ),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('아니오'));
    await tester.pumpAndSettle();
    expect(result, false);
  });
}
