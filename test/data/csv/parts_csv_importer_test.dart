import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/data/csv/parts_csv_importer.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

void main() {
  group('parseMaterial', () {
    test('표준 형식: 색상_두께T', () {
      expect(PartsCsvImporter.parseMaterial('화이트_18T'), ('화이트', 18.0));
      expect(PartsCsvImporter.parseMaterial('오크_15T'), ('오크', 15.0));
      expect(PartsCsvImporter.parseMaterial('자작_3T'), ('자작', 3.0));
    });

    test('소수 두께도 처리', () {
      expect(PartsCsvImporter.parseMaterial('화이트_18.5T'), ('화이트', 18.5));
    });

    test('형식이 안 맞으면 (전체, 0)', () {
      expect(PartsCsvImporter.parseMaterial('화이트'), ('화이트', 0.0));
      expect(PartsCsvImporter.parseMaterial(''), ('', 0.0));
      expect(PartsCsvImporter.parseMaterial('_18T'), ('_18T', 0.0));
    });

    test('색상명에 underscore 포함 — 마지막 _ 기준 분리', () {
      expect(PartsCsvImporter.parseMaterial('화이트_멜라민_18T'),
          ('화이트_멜라민', 18.0));
    });
  });

  group('parse — 0502전경인화이트.CSV 형식', () {
    const csv = '''﻿PART,W,D,T,MATERIAL,GRAIN,QTY,ARTICLE,EDGE1,EDGE2,EDGE3,EDGE4,FILE,GROOVE,ORIENTATION
이동선반,304.5,262.5,18.5,화이트_18T,0,4,선반3단장3도어,자작_1T,자작_1T,자작_1T,자작_1T,F1,,1
지판,1000.0,290.0,18.5,화이트_18T,1,1,선반3단장3도어,,,,,F2,,1
''';

    test('헤더 + 2행 → 2개 row', () {
      final rows = PartsCsvImporter.parse(csv);
      expect(rows.length, 2);
    });

    test('첫 행 매핑 정확', () {
      final rows = PartsCsvImporter.parse(csv);
      final r = rows[0];
      expect(r.label, '이동선반');
      expect(r.length, 304.5);
      expect(r.width, 262.5);
      expect(r.thickness, 18.5);
      expect(r.materialColorName, '화이트');
      expect(r.materialThickness, 18.0);
      expect(r.grain, GrainDirection.none);
      expect(r.qty, 4);
      expect(r.article, '선반3단장3도어');
      expect(r.edges, ['자작_1T', '자작_1T', '자작_1T', '자작_1T']);
      expect(r.fileName, 'F1');
    });

    test('빈 EDGE 칼럼은 빈 문자열', () {
      final rows = PartsCsvImporter.parse(csv);
      expect(rows[1].edges, ['', '', '', '']);
      expect(rows[1].fileName, 'F2');
    });

    test('GRAIN=1 → lengthwise', () {
      final rows = PartsCsvImporter.parse(csv);
      expect(rows[1].grain, GrainDirection.lengthwise);
    });
  });

  group('parse — edge cases', () {
    test('빈 입력 → 빈 리스트', () {
      expect(PartsCsvImporter.parse(''), isEmpty);
    });

    test('헤더만 → 빈 리스트', () {
      expect(PartsCsvImporter.parse('PART,W,D,T,MATERIAL,GRAIN,QTY,ARTICLE'),
          isEmpty);
    });

    test('빈 PART 행은 스킵', () {
      const csv = '''PART,W,D,T,MATERIAL,GRAIN,QTY,ARTICLE
,100,100,18,화이트_18T,0,1,a
부품1,200,200,18,화이트_18T,0,2,a
''';
      final rows = PartsCsvImporter.parse(csv);
      expect(rows.length, 1);
      expect(rows[0].label, '부품1');
    });

    test('CRLF 줄바꿈 처리', () {
      const csv =
          'PART,W,D,T,MATERIAL,GRAIN,QTY,ARTICLE\r\n부품1,100,100,18,화이트_18T,0,1,a\r\n';
      final rows = PartsCsvImporter.parse(csv);
      expect(rows.length, 1);
    });
  });
}
