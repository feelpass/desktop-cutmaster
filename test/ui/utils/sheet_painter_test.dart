import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/cutting_plan.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/ui/utils/sheet_painter.dart';

/// Note: `Picture.toImage()` returns successfully on the headless test engine,
/// but `image.toByteData(format: png)` requires the real Flutter engine
/// (Skia codec) and hangs / times out under `flutter test`. So these tests
/// stop at picture-capture: that's enough to catch any runtime exception
/// inside the painter (canvas API breakage), which is the smoke-test goal.
void main() {
  test('SheetPainter draws sheet + parts + header without throwing', () async {
    final sheet = SheetLayout(
      stockSheetId: 's1',
      sheetLength: 1000,
      sheetWidth: 500,
      placed: const [
        PlacedPart(
          part: CutPart(
            id: 'p1',
            length: 200,
            width: 100,
            qty: 1,
            label: 'A',
            grainDirection: GrainDirection.none,
          ),
          x: 0,
          y: 0,
        ),
      ],
    );
    const stock = StockSheet(
      id: 's1',
      length: 1000,
      width: 500,
      qty: 1,
      label: '테스트 자재',
      grainDirection: GrainDirection.none,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    SheetPainter(
      sheet: sheet,
      stock: stock,
      showLabels: true,
      colorLookup: (_) => null,
      headerText: '시트 1 / 1 • 1000 × 500 mm • 테스트 자재',
      headerHeightPx: 32,
    ).paint(canvas, const Size(800, 432)); // 400 + 32 header

    final picture = recorder.endRecording();
    expect(picture, isNotNull);
    picture.dispose();
  });

  test('SheetPainter handles null stock + null header', () async {
    const sheet = SheetLayout(
      stockSheetId: 's1',
      sheetLength: 100,
      sheetWidth: 50,
      placed: [],
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    SheetPainter(
      sheet: sheet,
      stock: null,
      showLabels: false,
      colorLookup: (_) => null,
    ).paint(canvas, const Size(200, 100));
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
    picture.dispose();
  });
}
