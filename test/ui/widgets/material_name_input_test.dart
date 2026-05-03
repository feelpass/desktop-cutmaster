import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/widgets/material_name_input.dart';

class _FakeRepo extends PresetRepository {
  _FakeRepo(this.initial) : super(filePath: '/dev/null/x');
  final List<ColorPreset> initial;
  PresetState? _saved;
  @override
  Future<PresetState> load() async =>
      PresetState(colors: initial, parts: const [], stocks: const []);
  @override
  Future<void> save(PresetState s) async {
    _saved = s;
  }
}

Future<PresetsNotifier> _setupPresets(List<ColorPreset> seed) async {
  final notifier = PresetsNotifier(_FakeRepo(seed));
  await notifier.load();
  return notifier;
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('기존 프리셋 이름 입력 후 submit → 그 id로 onChanged', (tester) async {
    final presets = await _setupPresets([
      const ColorPreset(id: 'white-1', name: '화이트', argb: 0xFFFFFFFF),
      const ColorPreset(id: 'oak-1', name: '오크', argb: 0xFFAA8855),
    ]);
    String? captured;
    var captureCount = 0;
    await tester.pumpWidget(_wrap(MaterialNameInput(
      colorPresetId: null,
      presets: presets,
      onChanged: (id) {
        captured = id;
        captureCount++;
      },
    )));

    await tester.enterText(find.byType(TextFormField), '화이트');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(captureCount, greaterThanOrEqualTo(1));
    expect(captured, 'white-1');
  });

  testWidgets('빈 문자열 submit → onChanged(null)', (tester) async {
    final presets = await _setupPresets([
      const ColorPreset(id: 'white-1', name: '화이트', argb: 0xFFFFFFFF),
    ]);
    String? captured = 'INITIAL';
    var captureCount = 0;
    await tester.pumpWidget(_wrap(MaterialNameInput(
      colorPresetId: 'white-1',
      presets: presets,
      onChanged: (id) {
        captured = id;
        captureCount++;
      },
    )));

    await tester.enterText(find.byType(TextFormField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(captureCount, greaterThanOrEqualTo(1));
    expect(captured, isNull);
  });

  testWidgets('새 이름 submit → addColor 호출 + 새 id로 onChanged', (tester) async {
    final presets = await _setupPresets([
      const ColorPreset(id: 'white-1', name: '화이트', argb: 0xFFFFFFFF),
    ]);
    String? captured;
    await tester.pumpWidget(_wrap(MaterialNameInput(
      colorPresetId: null,
      presets: presets,
      onChanged: (id) => captured = id,
    )));

    await tester.enterText(find.byType(TextFormField), '메이플');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // 새 프리셋이 추가되었어야 함
    final created =
        presets.state.colors.firstWhere((c) => c.name == '메이플',
            orElse: () => const ColorPreset(id: '', name: '', argb: 0));
    expect(created.id.isNotEmpty, isTrue);
    expect(captured, created.id);
  });

  testWidgets('초기 colorPresetId가 있으면 텍스트 필드에 그 이름이 표시됨', (tester) async {
    final presets = await _setupPresets([
      const ColorPreset(id: 'oak-1', name: '오크', argb: 0xFFAA8855),
    ]);
    await tester.pumpWidget(_wrap(MaterialNameInput(
      colorPresetId: 'oak-1',
      presets: presets,
      onChanged: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('오크'), findsOneWidget);
  });

  testWidgets('모르는 colorPresetId면 빈 텍스트 필드', (tester) async {
    final presets = await _setupPresets([
      const ColorPreset(id: 'oak-1', name: '오크', argb: 0xFFAA8855),
    ]);
    await tester.pumpWidget(_wrap(MaterialNameInput(
      colorPresetId: 'unknown',
      presets: presets,
      onChanged: (_) {},
    )));
    await tester.pumpAndSettle();

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text ?? '', '');
  });

  testWidgets('showMaterialEditDialog: 기존 이름 입력 후 submit → onChanged + 닫힘',
      (tester) async {
    final presets = await _setupPresets([
      const ColorPreset(id: 'oak-1', name: '오크', argb: 0xFFAA8855),
    ]);
    String? captured = 'INITIAL';

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => showMaterialEditDialog(
              context: ctx,
              presets: presets,
              currentColorPresetId: null,
              onChanged: (id) => captured = id,
            ),
            child: const Text('open'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '오크');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(captured, 'oak-1');
    // 다이얼로그가 닫혔어야 함 (TextField가 더 이상 보이지 않음)
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('showMaterialEditDialog: 취소 → onChanged 호출 안 됨', (tester) async {
    final presets = await _setupPresets([
      const ColorPreset(id: 'oak-1', name: '오크', argb: 0xFFAA8855),
    ]);
    String? captured = 'INITIAL';
    var callCount = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => showMaterialEditDialog(
              context: ctx,
              presets: presets,
              currentColorPresetId: 'oak-1',
              onChanged: (id) {
                captured = id;
                callCount++;
              },
            ),
            child: const Text('open'),
          );
        }),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(callCount, 0);
    expect(captured, 'INITIAL');
  });
}
