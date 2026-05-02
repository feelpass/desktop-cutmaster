import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../domain/models/stock_sheet.dart' show GrainDirection;
import '../csv/parts_csv_importer.dart';

/// Excel(.xlsx / .xlsm) 파일을 ParsedPartRow 리스트로.
/// 첫 시트만 읽는다. 헤더는 첫 행으로 가정 (CSV importer와 동일 컬럼 규약).
///
/// MATERIAL 형식 `색상_두께T` 파싱은 [PartsCsvImporter.parseMaterial] 재사용.
class PartsExcelImporter {
  static List<ParsedPartRow> parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return const [];
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null || sheet.rows.isEmpty) return const [];

    final rawRows = sheet.rows;
    final header = rawRows.first.map(_cellAsString).toList();
    final colIndex = _columnIndices(header);

    final rows = <ParsedPartRow>[];
    for (var i = 1; i < rawRows.length; i++) {
      final cells = rawRows[i].map(_cellAsString).toList();
      final row = _mapRow(cells, colIndex);
      if (row != null) rows.add(row);
    }
    return rows;
  }

  /// Excel 셀(`Data?`)을 문자열로 평탄화.
  /// - null / 빈 셀 → ''
  /// - TextCellValue → 평문
  /// - IntCellValue / DoubleCellValue / BoolCellValue → 숫자/불리언 문자열
  /// - 그 외(Date/Time/Formula 등) → toString fallback
  static String _cellAsString(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    return v.toString().trim();
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

    final (name, mt) = PartsCsvImporter.parseMaterial(material);
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
