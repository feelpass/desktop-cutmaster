import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/cutting_plan.dart';

void main() {
  test('Segment exposes parts list and trim waste', () {
    const seg = Segment(offset: 0, length: 600, parts: [], trim: 100);
    expect(seg.offset, 0);
    expect(seg.length, 600);
    expect(seg.parts, isEmpty);
    expect(seg.trim, 100);
  });

  test('Strip composes multiple segments', () {
    const s = Strip(
      offset: 0,
      width: 400,
      length: 1220,
      segments: [
        Segment(offset: 0, length: 600, parts: [], trim: 0),
        Segment(offset: 600, length: 500, parts: [], trim: 100),
      ],
    );
    expect(s.segments.length, 2);
    expect(s.segments.last.trim, 100);
    expect(s.width, 400);
    expect(s.length, 1220);
  });

  test('CutSequence carries direction flag and strips list', () {
    const seq = CutSequence(verticalFirst: true, strips: []);
    expect(seq.verticalFirst, true);
    expect(seq.strips, isEmpty);
  });

  test('SheetLayout.cutSequence defaults to null (FFD mode)', () {
    const layout = SheetLayout(
      stockSheetId: 's1',
      placed: [],
      sheetLength: 2440,
      sheetWidth: 1220,
    );
    expect(layout.cutSequence, isNull);
  });

  test('SheetLayout accepts an explicit cutSequence (strip-cut mode)', () {
    const layout = SheetLayout(
      stockSheetId: 's1',
      placed: [],
      sheetLength: 2440,
      sheetWidth: 1220,
      cutSequence: CutSequence(verticalFirst: false, strips: []),
    );
    expect(layout.cutSequence, isNotNull);
    expect(layout.cutSequence!.verticalFirst, false);
  });
}
