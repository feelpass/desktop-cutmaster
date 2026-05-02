import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/csv/parts_csv_exporter.dart';
import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

void main() {
  const whitePreset = ColorPreset(id: 'cp_white', name: '화이트', argb: 0xFFFFFFFF);
  const oakPreset = ColorPreset(id: 'cp_oak', name: '오크', argb: 0xFFB58863);

  group('PartsCsvExporter.export', () {
    test('빈 입력 → 헤더만 (BOM 포함)', () {
      final csv = PartsCsvExporter.export(
        parts: const [],
        articleName: '',
        colors: const [],
      );
      expect(csv.codeUnitAt(0), 0xFEFF);
      final lines = csv.substring(1).split('\r\n');
      expect(lines.first,
          'PART,W,D,T,MATERIAL,GRAIN,QTY,ARTICLE,EDGE1,EDGE2,EDGE3,EDGE4,FILE,GROOVE,ORIENTATION');
      expect(lines.where((l) => l.isNotEmpty).length, 1);
    });

    test('1개 부품 → 표준 형식 (MATERIAL=색상_두께T, GRAIN=0, ORIENTATION=1)', () {
      final part = CutPart(
        id: 'p1',
        label: '이동선반',
        length: 304.5,
        width: 262.5,
        thickness: 18,
        qty: 4,
        colorPresetId: whitePreset.id,
        grainDirection: GrainDirection.none,
        edges: const ['자작_1T', '자작_1T', '자작_1T', '자작_1T'],
        fileName: '0502전경인화1011_01',
      );
      final csv = PartsCsvExporter.export(
        parts: [part],
        articleName: '선반3단장3도어',
        colors: const [whitePreset],
      );
      final lines = csv.substring(1).split('\r\n');
      expect(lines[1],
          '이동선반,304.5,262.5,18,화이트_18T,0,4,선반3단장3도어,자작_1T,자작_1T,자작_1T,자작_1T,0502전경인화1011_01,,1');
    });

    test('GrainDirection 매핑: none=0, lengthwise=1, widthwise=2', () {
      final parts = [
        CutPart(id: 'a', label: 'A', length: 100, width: 100, qty: 1,
            grainDirection: GrainDirection.none, colorPresetId: oakPreset.id, thickness: 18),
        CutPart(id: 'b', label: 'B', length: 100, width: 100, qty: 1,
            grainDirection: GrainDirection.lengthwise, colorPresetId: oakPreset.id, thickness: 18),
        CutPart(id: 'c', label: 'C', length: 100, width: 100, qty: 1,
            grainDirection: GrainDirection.widthwise, colorPresetId: oakPreset.id, thickness: 18),
      ];
      final csv = PartsCsvExporter.export(
        parts: parts,
        articleName: 'X',
        colors: const [oakPreset],
      );
      final lines = csv.substring(1).split('\r\n');
      // 4번째 컬럼이 MATERIAL, 5번째가 GRAIN
      expect(lines[1].split(',')[5], '0');
      expect(lines[2].split(',')[5], '1');
      expect(lines[3].split(',')[5], '2');
    });

    test('colorPresetId가 null이면 MATERIAL은 빈 문자열', () {
      final part = CutPart(
        id: 'p1', label: '미정', length: 100, width: 100, qty: 1,
        colorPresetId: null, thickness: 18,
      );
      final csv = PartsCsvExporter.export(
        parts: [part], articleName: 'X', colors: const [],
      );
      final lines = csv.substring(1).split('\r\n');
      expect(lines[1].split(',')[4], '');
    });

    test('label에 콤마가 있으면 따옴표로 감싸기', () {
      final part = CutPart(
        id: 'p1', label: '선반,상단', length: 100, width: 100, qty: 1,
        colorPresetId: whitePreset.id, thickness: 18,
      );
      final csv = PartsCsvExporter.export(
        parts: [part], articleName: 'X', colors: const [whitePreset],
      );
      final lines = csv.substring(1).split('\r\n');
      expect(lines[1].startsWith('"선반,상단",100'), isTrue);
    });

    test('thickness가 정수면 소수점 없이 (18 → "18", 18.5 → "18.5")', () {
      final p1 = CutPart(id: 'a', label: 'A', length: 100, width: 100, qty: 1,
          colorPresetId: whitePreset.id, thickness: 18);
      final p2 = CutPart(id: 'b', label: 'B', length: 100, width: 100, qty: 1,
          colorPresetId: whitePreset.id, thickness: 18.5);
      final csv = PartsCsvExporter.export(
        parts: [p1, p2], articleName: 'X', colors: const [whitePreset],
      );
      final lines = csv.substring(1).split('\r\n');
      // T는 4번째 컬럼 (idx 3), MATERIAL은 5번째 (idx 4)
      expect(lines[1].split(',')[3], '18');
      expect(lines[1].split(',')[4], '화이트_18T');
      expect(lines[2].split(',')[3], '18.5');
      expect(lines[2].split(',')[4], '화이트_18.5T');
    });
  });
}
