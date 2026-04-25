import 'preset_models.dart';

class ColorMatcher {
  ColorMatcher(this.colors, {this.maxDistance = 30.0});
  final List<ColorPreset> colors;
  final double maxDistance;

  /// argb의 가장 가까운 ColorPreset.id 반환. threshold 초과면 null.
  String? match(int argb) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    String? bestId;
    double bestDist = double.infinity;
    for (final c in colors) {
      final pr = (c.argb >> 16) & 0xFF;
      final pg = (c.argb >> 8) & 0xFF;
      final pb = c.argb & 0xFF;
      final dr = (r - pr).toDouble();
      final dg = (g - pg).toDouble();
      final db = (b - pb).toDouble();
      final d = (dr * dr + dg * dg + db * db); // squared
      if (d < bestDist) {
        bestDist = d;
        bestId = c.id;
      }
    }
    final dist = bestDist.isFinite ? bestDist : double.infinity;
    // sqrt 비교 대신 maxDistance^2 와 비교 — 미세 최적화
    if (dist > maxDistance * maxDistance) return null;
    return bestId;
  }
}
