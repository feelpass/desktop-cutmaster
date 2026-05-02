import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/excel/parts_excel_importer.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

/// 테스트 fixture 빌더 — `excel` 패키지의 writer로 in-memory .xlsx 생성.
/// 첫 행은 헤더, 나머지는 데이터 행. cell 값은 String / int / double / null 허용.
Uint8List _buildXlsx(List<List<Object?>> rows, {String sheetName = 'Sheet1'}) {
  final excel = Excel.createExcel();
  // createExcel은 기본적으로 'Sheet1'을 만든다. 다른 이름이면 새로 추가하고 기본 시트 제거.
  if (sheetName != 'Sheet1') {
    excel.copy('Sheet1', sheetName);
    excel.delete('Sheet1');
  }
  for (final row in rows) {
    excel.appendRow(
      sheetName,
      row.map<CellValue?>(_toCellValue).toList(),
    );
  }
  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('Failed to encode test xlsx');
  }
  return Uint8List.fromList(bytes);
}

CellValue? _toCellValue(Object? v) {
  if (v == null) return null;
  if (v is int) return IntCellValue(v);
  if (v is double) return DoubleCellValue(v);
  if (v is String) return TextCellValue(v);
  if (v is bool) return BoolCellValue(v);
  return TextCellValue(v.toString());
}

void main() {
  group('PartsExcelImporter.parse — 표준 형식', () {
    test('헤더 + 1행 → 부품 1개로 매핑', () {
      final bytes = _buildXlsx([
        ['PART', 'W', 'D', 'T', 'MATERIAL', 'GRAIN', 'QTY', 'ARTICLE'],
        ['이동선반', 304.5, 262.5, 18.5, '화이트_18T', 0, 4, '선반3단장3도어'],
      ]);

      final rows = PartsExcelImporter.parse(bytes);

      expect(rows.length, 1);
      final r = rows.first;
      expect(r.label, '이동선반');
      expect(r.length, 304.5);
      expect(r.width, 262.5);
      expect(r.thickness, 18.5);
      expect(r.materialColorName, '화이트');
      expect(r.materialThickness, 18.0);
      expect(r.grain, GrainDirection.none);
      expect(r.qty, 4);
      expect(r.article, '선반3단장3도어');
    });

    test('EDGE1~4 / FILE / GROOVE 매핑 + GRAIN=1 → lengthwise', () {
      final bytes = _buildXlsx([
        [
          'PART', 'W', 'D', 'T', 'MATERIAL', 'GRAIN', 'QTY', 'ARTICLE',
          'EDGE1', 'EDGE2', 'EDGE3', 'EDGE4', 'FILE', 'GROOVE',
        ],
        [
          '지판', 1000.0, 290.0, 18.5, '화이트_18T', 1, 1, '선반3단장3도어',
          '자작_1T', '자작_1T', '', '', 'F2', 'G1',
        ],
      ]);

      final rows = PartsExcelImporter.parse(bytes);
      expect(rows.length, 1);
      final r = rows.first;
      expect(r.grain, GrainDirection.lengthwise);
      expect(r.edges, ['자작_1T', '자작_1T', '', '']);
      expect(r.fileName, 'F2');
      expect(r.groove, 'G1');
    });
  });

  group('PartsExcelImporter.parse — edge cases', () {
    test('빈 워크북 → 빈 리스트', () {
      final bytes = _buildXlsx(const []);
      expect(PartsExcelImporter.parse(bytes), isEmpty);
    });

    test('헤더만 있는 시트 → 빈 리스트', () {
      final bytes = _buildXlsx([
        ['PART', 'W', 'D', 'T', 'MATERIAL', 'GRAIN', 'QTY', 'ARTICLE'],
      ]);
      expect(PartsExcelImporter.parse(bytes), isEmpty);
    });

    test('빈 PART 행은 스킵', () {
      final bytes = _buildXlsx([
        ['PART', 'W', 'D', 'T', 'MATERIAL', 'GRAIN', 'QTY', 'ARTICLE'],
        ['', 100, 100, 18, '화이트_18T', 0, 1, 'a'],
        ['부품1', 200, 200, 18, '화이트_18T', 0, 2, 'a'],
      ]);
      final rows = PartsExcelImporter.parse(bytes);
      expect(rows.length, 1);
      expect(rows.first.label, '부품1');
    });

    test('다중 시트 → 첫 시트만 사용', () {
      // Sheet1에는 부품 1개, Sheet2에는 부품 2개. parse는 Sheet1만.
      final excel = Excel.createExcel();
      excel.appendRow('Sheet1', [
        TextCellValue('PART'), TextCellValue('W'), TextCellValue('D'),
        TextCellValue('T'), TextCellValue('MATERIAL'), TextCellValue('GRAIN'),
        TextCellValue('QTY'), TextCellValue('ARTICLE'),
      ]);
      excel.appendRow('Sheet1', [
        TextCellValue('첫시트부품'), DoubleCellValue(100), DoubleCellValue(100),
        DoubleCellValue(18), TextCellValue('화이트_18T'), IntCellValue(0),
        IntCellValue(1), TextCellValue('a'),
      ]);
      excel.appendRow('Sheet2', [
        TextCellValue('PART'), TextCellValue('W'), TextCellValue('D'),
        TextCellValue('T'), TextCellValue('MATERIAL'), TextCellValue('GRAIN'),
        TextCellValue('QTY'), TextCellValue('ARTICLE'),
      ]);
      excel.appendRow('Sheet2', [
        TextCellValue('두번째시트부품A'), DoubleCellValue(50), DoubleCellValue(50),
        DoubleCellValue(18), TextCellValue('화이트_18T'), IntCellValue(0),
        IntCellValue(1), TextCellValue('a'),
      ]);
      final bytes = Uint8List.fromList(excel.encode()!);

      final rows = PartsExcelImporter.parse(bytes);
      expect(rows.length, 1);
      expect(rows.first.label, '첫시트부품');
    });
  });
}
