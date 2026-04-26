import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/models/cutting_plan.dart';
import '../../domain/models/stock_sheet.dart';
import 'sheet_painter.dart';

/// PNG export 시 시트 위쪽에 추가로 그리는 헤더 영역 높이(px).
/// `SheetPainter.headerHeightPx`와 같이 캔버스 총 높이에 더해진다.
const double _kPngHeaderHeightPx = 32;

/// 시트별 PNG 파일 저장. 기본 75dpi (메모리 압박 방지).
/// 시트별로 stock 정보를 lookup해서 색상까지 반영.
///
/// [colorLookup]은 ColorPreset.id → ARGB(int)를 매핑한다 (id가 unknown이면
/// null을 반환). 호출자(보통 위젯 트리)가 PresetsNotifier에서 closure로 만들어
/// 주입한다 — non-widget util이라 ref를 직접 들지 않는다.
Future<void> exportSheetsToPng(
  BuildContext context,
  CuttingPlan plan,
  List<StockSheet> stocks,
  bool showLabels, {
  required int? Function(String? colorPresetId) colorLookup,
  double dpi = 75,
}) async {
  final dir = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'PNG 저장 위치 선택',
  );
  if (dir == null) return;

  final stockById = {for (final s in stocks) s.id: s};
  final total = plan.sheets.length;

  for (int i = 0; i < plan.sheets.length; i++) {
    final s = plan.sheets[i];
    final stock = stockById[s.stockSheetId];
    final png = await _renderSheetToPng(
      s,
      stock,
      showLabels,
      dpi,
      colorLookup,
      sheetNum: i + 1,
      sheetTotal: total,
    );
    if (png == null) continue;
    final file = File('$dir/cutmaster-sheet-${i + 1}.png');
    await file.writeAsBytes(png);
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${plan.sheets.length}개 PNG 파일을 저장했습니다.')),
    );
  }
}

Future<Uint8List?> _renderSheetToPng(
  SheetLayout sheet,
  StockSheet? stock,
  bool showLabels,
  double dpi,
  int? Function(String? colorPresetId) colorLookup, {
  required int sheetNum,
  required int sheetTotal,
}) async {
  // mm → 인치 → 픽셀: dpi=75 기준 1mm ≈ 2.95px
  final pxPerMm = dpi / 25.4;
  final widthPx = (sheet.sheetLength * pxPerMm).round();
  final sheetHeightPx = (sheet.sheetWidth * pxPerMm).round();
  // 헤더 영역만큼 캔버스 높이 확장 (헤더가 잘리지 않도록).
  final totalHeightPx = sheetHeightPx + _kPngHeaderHeightPx.round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(widthPx.toDouble(), totalHeightPx.toDouble());

  final headerText = stock != null
      ? '시트 $sheetNum / $sheetTotal • '
          '${sheet.sheetLength.toStringAsFixed(0)} × '
          '${sheet.sheetWidth.toStringAsFixed(0)} mm'
          '${stock.label.isNotEmpty ? " • ${stock.label}" : ""}'
      : '시트 $sheetNum / $sheetTotal • '
          '${sheet.sheetLength.toStringAsFixed(0)} × '
          '${sheet.sheetWidth.toStringAsFixed(0)} mm';

  SheetPainter(
    sheet: sheet,
    stock: stock,
    showLabels: showLabels,
    colorLookup: colorLookup,
    headerText: headerText,
    headerHeightPx: _kPngHeaderHeightPx,
  ).paint(canvas, size);

  final picture = recorder.endRecording();
  final image = await picture.toImage(widthPx, totalHeightPx);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}
