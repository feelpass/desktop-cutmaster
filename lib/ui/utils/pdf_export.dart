import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models/cutting_plan.dart';
import '../../domain/models/plan_summary.dart';
import '../../domain/models/stock_sheet.dart';
import 'sheet_painter.dart';

/// PDF 한글 출력을 위한 Pretendard 폰트. 첫 호출 시 1회 로드, 이후 캐시.
pw.Font? _cachedFont;
Future<pw.Font> _loadKoreanFont() async {
  if (_cachedFont != null) return _cachedFont!;
  final data = await rootBundle.load('assets/fonts/Pretendard-Regular.ttf');
  _cachedFont = pw.Font.ttf(data);
  return _cachedFont!;
}

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
  required String? Function(String? colorPresetId) colorName,
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

  // 진행 표시 — raster가 무거우면 사용자에게 즉시 피드백 (몇 초 걸릴 수 있음).
  final messenger = context.mounted ? ScaffoldMessenger.of(context) : null;
  messenger?.showSnackBar(
    SnackBar(
      content: Text('PDF 생성 중… (${plan.sheets.length}개 시트)'),
      duration: const Duration(seconds: 30),
    ),
  );
  // SnackBar가 그려질 수 있게 한 프레임 양보.
  await Future<void>.delayed(Duration.zero);

  final stockById = {for (final s in stocks) s.id: s};
  final korean = await _loadKoreanFont();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: korean,
      bold: korean, // Regular만 임베드 — bold 요청 시 동일 폰트 fallback
    ),
  );

  // 첫 페이지: 재료/부품 요약 표.
  final summary = PlanSummary.fromPlan(plan, colorName: colorName);
  doc.addPage(_buildSummaryPage(summary));

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
    // 시트 사이 한 프레임 양보 — UI freeze 방지.
    await Future<void>.delayed(Duration.zero);
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
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(content: Text('${plan.sheets.length}개 시트 PDF로 저장했습니다.')),
    );
  }
}

/// 첫 페이지: 재료 사용량 표 + 부품 목록 표.
pw.Page _buildSummaryPage(PlanSummary s) {
  final dateStr = DateTime.now().toIso8601String().substring(0, 10);
  return pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => [
      pw.Text('컷마스터 최적화 결과',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('작성일 $dateStr',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 16),

      // KPI 한 줄.
      pw.Text(
        '효율 ${s.efficiencyPercent.toStringAsFixed(1)}%   '
        '· 시트 ${s.totalSheets}장   '
        '· 부품 ${s.totalPlacedParts}개   '
        '· 절단 ${s.cutsAreEstimated ? "≈" : ""}${s.totalCuts}회',
        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
      ),
      pw.SizedBox(height: 18),

      // 재료 표.
      pw.Text('재료',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['자재', '시트 수', '사용 면적 (m²)'],
        data: [
          for (final m in s.materialUsages)
            [
              m.name,
              m.sheetCount.toString(),
              (m.usedAreaMm2 / 1e6).toStringAsFixed(3),
            ],
        ],
        headerStyle:
            pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
        },
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),

      pw.SizedBox(height: 18),

      // 부품 표.
      pw.Text('부품',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['부품명', '길이 (mm)', '폭 (mm)', '자재', '수량'],
        data: [
          for (final p in s.partGroups)
            [
              p.label,
              p.length.toStringAsFixed(0),
              p.width.toStringAsFixed(0),
              p.materialName,
              p.qty.toString(),
            ],
        ],
        headerStyle:
            pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 10),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerLeft,
          4: pw.Alignment.centerRight,
        },
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellPadding:
            const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
    ],
  );
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
