import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/project.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';

void main() {
  test('v2 JSON loads with default solver fields (ffd / auto / 3 / all on)', () {
    final v2Json = <String, dynamic>{
      'schemaVersion': 2,
      'id': 'p1',
      'name': 'legacy',
      'kerf': 3.0,
      'grainLocked': false,
      'showPartLabels': true,
      'useSingleSheet': false,
      'showShortcutHints': true,
      'stocks': const [],
      'parts': const [],
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
    };

    final p = Project.fromJson(v2Json);
    expect(p.solverMode, SolverMode.ffd);
    expect(p.stripDirection, StripDirection.auto);
    expect(p.maxStages, 3);
    expect(p.preferSameWidth, true);
    expect(p.minimizeCuts, true);
    expect(p.minimizeWaste, true);
  });

  test('v2 JSON with garbage solver field falls back to default', () {
    final j = <String, dynamic>{
      'schemaVersion': 2,
      'id': 'p2',
      'name': 'corrupt',
      'kerf': 3.0,
      'grainLocked': false,
      'showPartLabels': true,
      'useSingleSheet': false,
      'showShortcutHints': true,
      'stocks': const [],
      'parts': const [],
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
      'solverMode': 'unknownMode',  // garbage value — must fall back
    };
    final p = Project.fromJson(j);
    expect(p.solverMode, SolverMode.ffd);
  });
}
