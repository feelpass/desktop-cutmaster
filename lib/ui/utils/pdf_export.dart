import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/cutting_plan.dart';
import '../../domain/models/stock_sheet.dart';
import 'sheet_painter.dart';

/// 모든 시트를 한 PDF 파일에 시트별 페이지로 내보낸다 (A4 가로).
/// 페이지 헤더(시트 번호/치수/자재명/효율) + 본문(시트 이미지 raster) + 푸터(앱명·날짜).
///
/// [colorLookup]은 PNG export와 같은 시그니처 — ColorPreset.id → ARGB(int).
/// [rasterDpi]는 raster 해상도. A4 가로(297mm) 폭에 100dpi이면 ~1170px → 인쇄 적합.
Future<void> exportSheetsToPdf(
  BuildContext context,
  CuttingPlan plan,
  List<StockSheet> stocks,
  bool showLabels, {
  required int? Function(String? colorPresetId) colorLookup,
  double rasterDpi = 100,
}) async {
  final initialFileName =
      'cutmaster-${DateTime.now().toIso8601String().substring(0, 10)}.pdf';
  final outPath = await FilePicker.platform.saveFile(
    dialogTitle: 'PDF 저장 위치 선택',
    fileName: initialFileName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (outPath == null) return;

  final stockById = {for (final s in stocks) s.id: s};
  final doc = pw.Document();

  for (int i = 0; i < plan.sheets.length; i++) {
    final s = plan.sheets[i];
    final stock = stockById[s.stockSheetId];
    final imgBytes = await _renderSheetPng(
      s,
      stock,
      showLabels,
      rasterDpi,
      colorLookup,
    );
    if (imgBytes == null) continue;

    final headerText = _headerText(
      s,
      stock,
      sheetNum: i + 1,
      sheetTotal: plan.sheets.length,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              headerText,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
            ),
            pw.SizedBox(height: 6),
            pw.Expanded(
              child: pw.Center(
                child: pw.Image(
                  pw.MemoryImage(imgBytes),
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'cutmaster · ${DateTime.now().toIso8601String().substring(0, 10)}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final bytes = await doc.save();
  await File(outPath).writeAsBytes(bytes);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${plan.sheets.length}개 시트 PDF로 저장했습니다.')),
    );
  }
}

String _headerText(
  SheetLayout s,
  StockSheet? stock, {
  required int sheetNum,
  required int sheetTotal,
}) {
  final dims =
      '${s.sheetLength.toStringAsFixed(0)} × ${s.sheetWidth.toStringAsFixed(0)} mm';
  final eff = '${s.usedPercent.toStringAsFixed(1)}%';
  if (stock != null && stock.label.isNotEmpty) {
    return '시트 $sheetNum / $sheetTotal · $dims · ${stock.label} · 효율 $eff';
  }
  return '시트 $sheetNum / $sheetTotal · $dims · 효율 $eff';
}

/// SheetPainter를 raster로 PNG bytes로 변환. PDF 페이지 헤더는
/// `pw.Text`가 따로 그리므로 [SheetPainter.headerText]는 null로 둔다 (이중 헤더 방지).
Future<Uint8List?> _renderSheetPng(
  SheetLayout sheet,
  StockSheet? stock,
  bool showLabels,
  double dpi,
  int? Function(String? colorPresetId) colorLookup,
) async {
  final pxPerMm = dpi / 25.4;
  final widthPx = (sheet.sheetLength * pxPerMm).round();
  final heightPx = (sheet.sheetWidth * pxPerMm).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  SheetPainter(
    sheet: sheet,
    stock: stock,
    showLabels: showLabels,
    colorLookup: colorLookup,
    headerText: null,
  ).paint(canvas, Size(widthPx.toDouble(), heightPx.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(widthPx, heightPx);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}
