import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/solver_mode.dart';

void main() {
  test('SolverMode has ffd and stripCut values', () {
    expect(SolverMode.values, [SolverMode.ffd, SolverMode.stripCut]);
  });

  test('StripDirection has three values in expected order', () {
    expect(StripDirection.values, [
      StripDirection.verticalFirst,
      StripDirection.horizontalFirst,
      StripDirection.auto,
    ]);
  });

  test('SolverMode.fromName roundtrips', () {
    for (final m in SolverMode.values) {
      expect(SolverMode.fromName(m.name), m);
    }
  });

  test('StripDirection.fromName roundtrips', () {
    for (final d in StripDirection.values) {
      expect(StripDirection.fromName(d.name), d);
    }
  });

  test('SolverMode.fromName falls back to ffd on unknown', () {
    expect(SolverMode.fromName('garbage'), SolverMode.ffd);
  });

  test('StripDirection.fromName falls back to auto on unknown', () {
    expect(StripDirection.fromName('garbage'), StripDirection.auto);
  });
}
