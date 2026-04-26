import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/project.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';

void main() {
  test('Project.toJson / fromJson roundtrip preserves all fields', () {
    final orig = Project.create(id: 'p1', name: '책장').copyWith(
      stocks: [
        const StockSheet(
          id: 's1', length: 2440, width: 1220, qty: 2,
          label: '12T', grainDirection: GrainDirection.lengthwise,
          colorPresetId: 'cp_walnut',
        ),
      ],
      parts: [
        const CutPart(
          id: 'pa1', length: 600, width: 400, qty: 4,
          label: '문짝', grainDirection: GrainDirection.widthwise,
        ),
      ],
      kerf: 5,
      grainLocked: true,
      showPartLabels: false,
      useSingleSheet: true,
      showShortcutHints: false,
    );

    final json = orig.toJson();
    expect(json['schemaVersion'], 3);

    final back = Project.fromJson(json);
    expect(back.id, orig.id);
    expect(back.name, orig.name);
    expect(back.stocks, orig.stocks);
    expect(back.parts, orig.parts);
    expect(back.kerf, orig.kerf);
    expect(back.grainLocked, orig.grainLocked);
    expect(back.showPartLabels, orig.showPartLabels);
    expect(back.useSingleSheet, orig.useSingleSheet);
    expect(back.showShortcutHints, orig.showShortcutHints);
    expect(back.createdAt, orig.createdAt);
  });

  test('fromJson rejects unknown future schemaVersion', () {
    expect(
      () => Project.fromJson({'schemaVersion': 999, 'id': 'x', 'name': 'y'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('showShortcutHints defaults to true when missing from JSON', () {
    // 기존 v2 파일에는 이 키가 없을 수 있다 — backward-compatible read 검증.
    final json = {
      'schemaVersion': 2,
      'id': 'p1',
      'name': 'legacy',
      'kerf': 3,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final p = Project.fromJson(json);
    expect(p.showShortcutHints, true);
  });

  test('showShortcutHints round-trips with explicit false', () {
    final orig = Project.create(id: 'p1', name: 'hints off')
        .copyWith(showShortcutHints: false);
    final json = orig.toJson();
    expect(json['showShortcutHints'], false);
    final back = Project.fromJson(json);
    expect(back.showShortcutHints, false);
  });

  test('Project v3 roundtrip preserves new strip-cut fields', () {
    final orig = Project.create(id: 'p1', name: '서랍').copyWith(
      solverMode: SolverMode.stripCut,
      stripDirection: StripDirection.horizontalFirst,
      maxStages: 4,
      preferSameWidth: false,
      minimizeCuts: true,
      minimizeWaste: false,
    );

    final json = orig.toJson();
    expect(json['schemaVersion'], 3);
    expect(json['solverMode'], 'stripCut');
    expect(json['stripDirection'], 'horizontalFirst');
    expect(json['maxStages'], 4);
    expect(json['preferSameWidth'], false);
    expect(json['minimizeCuts'], true);
    expect(json['minimizeWaste'], false);

    final back = Project.fromJson(json);
    expect(back.solverMode, SolverMode.stripCut);
    expect(back.stripDirection, StripDirection.horizontalFirst);
    expect(back.maxStages, 4);
    expect(back.preferSameWidth, false);
    expect(back.minimizeCuts, true);
    expect(back.minimizeWaste, false);
  });

  test('Project default values for new strip-cut fields', () {
    final p = Project.create(id: 'p2', name: 'default test');
    expect(p.solverMode, SolverMode.ffd);
    expect(p.stripDirection, StripDirection.auto);
    expect(p.maxStages, 3);
    expect(p.preferSameWidth, true);
    expect(p.minimizeCuts, true);
    expect(p.minimizeWaste, true);
  });
}
