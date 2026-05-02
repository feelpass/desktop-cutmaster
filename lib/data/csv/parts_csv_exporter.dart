import '../../domain/models/cut_part.dart';
import '../../domain/models/stock_sheet.dart' show GrainDirection;
import '../preset/preset_models.dart';

/// 부품 리스트를 CSV 문자열로 직렬화.
/// 헤더는 PartsCsvImporter와 호환되며 ORIENTATION 컬럼도 포함(항상 1).
/// BOM(0xFEFF) + CRLF로 윈도우/한글 환경 호환.
class PartsCsvExporter {
  static const _header =
      'PART,W,D,T,MATERIAL,GRAIN,QTY,ARTICLE,EDGE1,EDGE2,EDGE3,EDGE4,FILE,GROOVE,ORIENTATION';

  static String export({
    required List<CutPart> parts,
    required String articleName,
    required List<ColorPreset> colors,
  }) {
    final colorMap = {for (final c in colors) c.id: c};
    final buf = StringBuffer();
    buf.writeCharCode(0xFEFF);
    buf.write(_header);
    buf.write('\r\n');
    for (final p in parts) {
      buf.write(_rowFor(p, articleName, colorMap));
      buf.write('\r\n');
    }
    return buf.toString();
  }

  static String _rowFor(
      CutPart p, String article, Map<String, ColorPreset> colorMap) {
    final color = p.colorPresetId == null ? null : colorMap[p.colorPresetId];
    final material = color == null ? '' : '${color.name}_${_fmtNum(p.thickness)}T';
    final cells = <String>[
      p.label,
      _fmtNum(p.length),
      _fmtNum(p.width),
      _fmtNum(p.thickness),
      material,
      _grainCode(p.grainDirection),
      p.qty.toString(),
      article,
      _safe(p.edges, 0),
      _safe(p.edges, 1),
      _safe(p.edges, 2),
      _safe(p.edges, 3),
      p.fileName,
      p.groove,
      '1',
    ];
    return cells.map(_escape).join(',');
  }

  static String _safe(List<String> edges, int i) =>
      i < edges.length ? edges[i] : '';

  static String _grainCode(GrainDirection g) {
    switch (g) {
      case GrainDirection.lengthwise:
        return '1';
      case GrainDirection.widthwise:
        return '2';
      case GrainDirection.none:
        return '0';
    }
  }

  /// 정수 두께/치수(18.0)는 "18", 소수(18.5)는 "18.5" 형태.
  static String _fmtNum(double v) {
    if (v == v.truncate()) return v.toInt().toString();
    return v.toString();
  }

  /// CSV 셀 escape: 콤마, 큰따옴표, CR/LF 포함 시 큰따옴표로 감싸고 내부 따옴표는 두 번.
  static String _escape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
