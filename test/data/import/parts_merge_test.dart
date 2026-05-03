import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/data/import/parts_merge.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

CutPart _p({
  required String id,
  required String label,
  required String colorId,
  required double length,
  required double width,
  required double thickness,
  int qty = 1,
  GrainDirection grain = GrainDirection.none,
}) =>
    CutPart(
      id: id,
      label: label,
      colorPresetId: colorId,
      length: length,
      width: width,
      thickness: thickness,
      qty: qty,
      grainDirection: grain,
    );

void main() {
  group('detectConflicts', () {
    test('5-튜플 모두 동일 → 충돌 1건', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반_상',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 3,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반_상',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 2,
        ),
      ];

      final conflicts = detectConflicts(existing, incoming);

      expect(conflicts, hasLength(1));
      expect(conflicts.first.existingIndex, 0);
      expect(conflicts.first.existing.id, 'a');
      expect(conflicts.first.incoming.id, 'b');
    });

    test('빈 incoming → 충돌 0건', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      expect(detectConflicts(existing, const []), isEmpty);
    });

    test('label만 같고 자재 다름 → 충돌 아님', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'oak',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      expect(detectConflicts(existing, incoming), isEmpty);
    });

    test('label+자재 같고 사이즈 다름 → 충돌 아님', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 800,
          width: 300,
          thickness: 18,
        ),
      ];
      expect(detectConflicts(existing, incoming), isEmpty);
    });

    test('두께만 다름 → 충돌 아님', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 15,
        ),
      ];
      expect(detectConflicts(existing, incoming), isEmpty);
    });

    test('grain만 다르고 5-튜플 동일 → 충돌 (grain은 키 아님)', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          grain: GrainDirection.none,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          grain: GrainDirection.lengthwise,
        ),
      ];
      expect(detectConflicts(existing, incoming), hasLength(1));
    });

    test('한 incoming이 여러 existing과 매치 → 첫 번째 매치만', () {
      final existing = [
        _p(
          id: 'a1',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
        _p(
          id: 'a2',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final conflicts = detectConflicts(existing, incoming);
      expect(conflicts, hasLength(1));
      expect(conflicts.first.existingIndex, 0);
    });

    test('label.trim() 기반 비교 (앞뒤 공백 무시)', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '  선반  ',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      expect(detectConflicts(existing, incoming), hasLength(1));
    });
  });

  group('applyMerge — addQty', () {
    test('충돌 행 qty 합산 (3+2=5), 다른 필드는 기존 유지', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 3,
          grain: GrainDirection.none,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 2,
          grain: GrainDirection.lengthwise,
        ),
      ];

      final result = applyMerge(existing, incoming, MergeAction.addQty);

      expect(result.mergedParts, hasLength(1));
      expect(result.mergedParts[0].id, 'a'); // 기존 id 유지
      expect(result.mergedParts[0].qty, 5);
      expect(result.mergedParts[0].grainDirection, GrainDirection.none);
      expect(result.qtyMergedCount, 1);
      expect(result.addedCount, 0);
    });

    test('비충돌 신규 행은 append, 충돌은 합산 — 둘 다 작동', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 1,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 4,
        ),
        _p(
          id: 'c',
          label: '신규',
          colorId: 'oak',
          length: 500,
          width: 200,
          thickness: 15,
          qty: 2,
        ),
      ];
      final result = applyMerge(existing, incoming, MergeAction.addQty);
      expect(result.mergedParts, hasLength(2));
      expect(result.mergedParts[0].qty, 5);
      expect(result.mergedParts[1].id, 'c');
      expect(result.qtyMergedCount, 1);
      expect(result.addedCount, 1);
    });
  });

  group('applyMerge — renameAndAdd', () {
    test('"X" 충돌 → "X (2)"로 추가, 기존 행 보존', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 3,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 2,
        ),
      ];
      final result =
          applyMerge(existing, incoming, MergeAction.renameAndAdd);

      expect(result.mergedParts, hasLength(2));
      expect(result.mergedParts[0].id, 'a'); // 기존 보존
      expect(result.mergedParts[0].label, '선반');
      expect(result.mergedParts[0].qty, 3);
      expect(result.mergedParts[1].id, 'b'); // 신규 추가
      expect(result.mergedParts[1].label, '선반 (2)');
      expect(result.mergedParts[1].qty, 2);
      expect(result.renamedCount, 1);
    });

    test('기존에 "X", "X (2)" 모두 있으면 → "X (3)"', () {
      final existing = [
        _p(
          id: 'a1',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
        _p(
          id: 'a2',
          label: '선반 (2)',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final result =
          applyMerge(existing, incoming, MergeAction.renameAndAdd);
      expect(result.mergedParts, hasLength(3));
      expect(result.mergedParts[2].label, '선반 (3)');
    });

    test('같은 배치 내 동일 label 2개 충돌 → "X (2)", "X (3)"', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final incoming = [
        _p(
          id: 'b1',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
        _p(
          id: 'b2',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final result =
          applyMerge(existing, incoming, MergeAction.renameAndAdd);
      expect(result.mergedParts, hasLength(3));
      expect(result.mergedParts[1].label, '선반 (2)');
      expect(result.mergedParts[2].label, '선반 (3)');
      expect(result.renamedCount, 2);
    });

    test('base가 이미 "(5)"로 끝나면 base에서 떼고 (2)부터 — 누적 방지', () {
      // 기존에 "선반 (5)"라는 부품이 이미 있고, 신규도 같은 label로 들어옴
      final existing = [
        _p(
          id: 'a',
          label: '선반 (5)',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반 (5)',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final result =
          applyMerge(existing, incoming, MergeAction.renameAndAdd);
      expect(result.mergedParts, hasLength(2));
      // base "선반"으로부터 다시 시작. "선반"이 없으니 첫 후보 "선반 (2)" 사용.
      expect(result.mergedParts[1].label, '선반 (2)');
    });
  });

  group('applyMerge — cancel', () {
    test('mergedParts == existing (변경 없음), 카운트 모두 0', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
        ),
        _p(
          id: 'c',
          label: '신규',
          colorId: 'oak',
          length: 500,
          width: 200,
          thickness: 15,
        ),
      ];
      final result = applyMerge(existing, incoming, MergeAction.cancel);
      expect(result.mergedParts, hasLength(1));
      expect(result.mergedParts[0].id, 'a');
      expect(result.addedCount, 0);
      expect(result.overwrittenCount, 0);
      expect(result.qtyMergedCount, 0);
      expect(result.renamedCount, 0);
    });
  });

  group('applyMerge — overwrite', () {
    test('충돌 행은 신규로 교체, 비충돌 신규는 append', () {
      final existing = [
        _p(
          id: 'a',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 3,
          grain: GrainDirection.none,
        ),
        _p(
          id: 'a2',
          label: '측판',
          colorId: 'oak',
          length: 800,
          width: 400,
          thickness: 15,
          qty: 4,
        ),
      ];
      final incoming = [
        _p(
          id: 'b',
          label: '선반',
          colorId: 'white',
          length: 600,
          width: 300,
          thickness: 18,
          qty: 7,
          grain: GrainDirection.lengthwise,
        ),
        _p(
          id: 'c',
          label: '신규',
          colorId: 'white',
          length: 500,
          width: 200,
          thickness: 18,
          qty: 1,
        ),
      ];

      final result = applyMerge(existing, incoming, MergeAction.overwrite);

      expect(result.mergedParts, hasLength(3));
      // 0: 선반 — 신규 값으로 교체 (qty=7, grain=lengthwise, id는 신규 id)
      expect(result.mergedParts[0].label, '선반');
      expect(result.mergedParts[0].qty, 7);
      expect(result.mergedParts[0].grainDirection, GrainDirection.lengthwise);
      expect(result.mergedParts[0].id, 'b');
      // 1: 측판 — 그대로
      expect(result.mergedParts[1].id, 'a2');
      // 2: 신규 — append
      expect(result.mergedParts[2].id, 'c');

      expect(result.overwrittenCount, 1);
      expect(result.addedCount, 1);
      expect(result.qtyMergedCount, 0);
      expect(result.renamedCount, 0);
    });
  });
}
