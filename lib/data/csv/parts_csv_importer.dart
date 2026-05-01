import '../../domain/models/stock_sheet.dart' show GrainDirection;

/// CSV 한 행을 파싱한 결과. ColorPreset 매칭은 호출자(UI 계층)가 책임짐.
class ParsedPartRow {
  final String label;
  final double length; // CSV의 W
  final double width; // CSV의 D
  final double thickness; // CSV의 T
  final String materialColorName; // "화이트_18T" → "화이트"
  final double materialThickness; // "화이트_18T" → 18
  final GrainDirection grain;
  final int qty;
  final String article;

  /// CSV의 EDGE1~4. 항상 길이 4, 빈 면은 ''.
  final List<String> edges;

  /// CSV의 FILE — 도면 파일명/식별자.
  final String fileName;

  /// CSV의 GROOVE — 홈 가공.
  final String groove;

  const ParsedPartRow({
    required this.label,
    required this.length,
    required this.width,
    required this.thickness,
    required this.materialColorName,
    required this.materialThickness,
    required this.grain,
    required this.qty,
    required this.article,
    this.edges = const ['', '', '', ''],
    this.fileName = '',
    this.groove = '',
  });
}

class PartsCsvImporter {
  /// CSV 텍스트를 ParsedPartRow 리스트로. 빈 줄 / BOM / 따옴표 처리.
  /// 헤더는 첫 줄로 가정 (PART, W, D, T, MATERIAL, GRAIN, QTY, ARTICLE, ...).
  ///
  /// MATERIAL 형식 `색상_두께T` (예: `화이트_18T`, `오크_15T`)을 파싱해
  /// 색상명과 두께를 분리한다. 형식이 맞지 않으면 색상명에 통째로,
  /// 두께는 행의 T 칼럼 값을 fallback으로 쓴다.
  static List<ParsedPartRow> parse(String csvText) {
    final lines = _splitLines(_stripBom(csvText));
    if (lines.isEmpty) return const [];

    final header = _parseRow(lines.first);
    final colIndex = _columnIndices(header);

    final rows = <ParsedPartRow>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cells = _parseRow(line);
      final row = _mapRow(cells, colIndex);
      if (row != null) rows.add(row);
    }
    return rows;
  }

  /// MATERIAL 단일 문자열 파서. public — 테스트와 UI 둘 다에서 쓴다.
  /// 형식: `<색상명>_<두께>T` (예: `화이트_18T` → ('화이트', 18.0)).
  /// 매칭 실패 시 (전체 문자열, 0.0) 반환 — fallback 두께는 호출자가 채움.
  static (String name, double thickness) parseMaterial(String material) {
    final m = material.trim();
    if (m.isEmpty) return ('', 0);
    final idx = m.lastIndexOf('_');
    if (idx <= 0 || idx >= m.length - 1) return (m, 0);
    final namePart = m.substring(0, idx);
    final tickPart = m.substring(idx + 1);
    if (!tickPart.endsWith('T') && !tickPart.endsWith('t')) {
      return (m, 0);
    }
    final num = tickPart.substring(0, tickPart.length - 1);
    final t = double.tryParse(num);
    if (t == null) return (m, 0);
    return (namePart, t);
  }

  static String _stripBom(String s) {
    if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) return s.substring(1);
    return s;
  }

  static List<String> _splitLines(String s) {
    return s.split(RegExp(r'\r\n|\n|\r')).where((l) => l.isNotEmpty).toList();
  }

  /// 단순 CSV row 파서 — 따옴표로 감싼 셀 안의 콤마는 보존.
  static List<String> _parseRow(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuote) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuote = false;
          }
        } else {
          buf.write(c);
        }
      } else {
        if (c == ',') {
          out.add(buf.toString());
          buf.clear();
        } else if (c == '"') {
          inQuote = true;
        } else {
          buf.write(c);
        }
      }
    }
    out.add(buf.toString());
    return out;
  }

  static Map<String, int> _columnIndices(List<String> header) {
    final map = <String, int>{};
    for (var i = 0; i < header.length; i++) {
      map[header[i].trim().toUpperCase()] = i;
    }
    return map;
  }

  static String? _cell(List<String> cells, int? idx) {
    if (idx == null || idx < 0 || idx >= cells.length) return null;
    return cells[idx].trim();
  }

  static ParsedPartRow? _mapRow(List<String> cells, Map<String, int> idx) {
    final partName = _cell(cells, idx['PART']) ?? '';
    if (partName.isEmpty) return null;

    final w = double.tryParse(_cell(cells, idx['W']) ?? '') ?? 0;
    final d = double.tryParse(_cell(cells, idx['D']) ?? '') ?? 0;
    final t = double.tryParse(_cell(cells, idx['T']) ?? '') ?? 18;
    final material = _cell(cells, idx['MATERIAL']) ?? '';
    final grainStr = _cell(cells, idx['GRAIN']) ?? '0';
    final qty = int.tryParse(_cell(cells, idx['QTY']) ?? '') ?? 1;
    final article = _cell(cells, idx['ARTICLE']) ?? '';
    final edges = <String>[
      _cell(cells, idx['EDGE1']) ?? '',
      _cell(cells, idx['EDGE2']) ?? '',
      _cell(cells, idx['EDGE3']) ?? '',
      _cell(cells, idx['EDGE4']) ?? '',
    ];
    final fileName = _cell(cells, idx['FILE']) ?? '';
    final groove = _cell(cells, idx['GROOVE']) ?? '';

    final (name, mt) = parseMaterial(material);
    final materialThickness = mt == 0 ? t : mt;

    return ParsedPartRow(
      label: partName,
      length: w,
      width: d,
      thickness: t,
      materialColorName: name,
      materialThickness: materialThickness,
      grain: _parseGrain(grainStr),
      qty: qty,
      article: article,
      edges: edges,
      fileName: fileName,
      groove: groove,
    );
  }

  /// CSV의 GRAIN 값 → GrainDirection.
  /// 0 = none, 1 = lengthwise, 2 = widthwise (관행적 매핑).
  static GrainDirection _parseGrain(String s) {
    final n = int.tryParse(s.trim()) ?? 0;
    switch (n) {
      case 1:
        return GrainDirection.lengthwise;
      case 2:
        return GrainDirection.widthwise;
      default:
        return GrainDirection.none;
    }
  }
}
