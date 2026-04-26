/// 솔버 모드. ffd = 자유 배치 (효율 우선), stripCut = panel saw 호환 (실작업 가능).
enum SolverMode {
  ffd,
  stripCut;

  static SolverMode fromName(String name) =>
      SolverMode.values.firstWhere((m) => m.name == name, orElse: () => ffd);
}

/// strip-cut 모드의 절단 방향.
enum StripDirection {
  /// 세로 풀컷 → 가로 분할.
  verticalFirst,

  /// 가로 풀컷 → 세로 분할.
  horizontalFirst,

  /// 두 방향 모두 풀고 더 나은 쪽 선택.
  auto;

  static StripDirection fromName(String name) =>
      StripDirection.values.firstWhere((d) => d.name == name, orElse: () => auto);
}
