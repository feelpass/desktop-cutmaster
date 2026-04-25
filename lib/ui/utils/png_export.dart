import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/models/cutting_plan.dart';
import '../../domain/models/stock_sheet.dart';
import 'part_color.dart';

/// 시트별 PNG 파일 저장. 기본 75dpi (메모리 압박 방지).
/// 시트별로 stock 정보를 lookup해서 색상까지 반영.
Future<void> exportSheetsToPng(
  BuildContext context,
  CuttingPlan plan,
  List<StockSheet> stocks,
  bool showLabels, {
  double dpi = 75,
}) async {
  final dir = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'PNG 저장 위치 선택',
  );
  if (dir == null) return;

  final stockById = {for (final s in stocks) s.id: s};

  for (int i = 0; i < plan.sheets.length; i++) {
    final s = plan.sheets[i];
    final stock = stockById[s.stockSheetId];
    final png = await _renderSheetToPng(s, stock, showLabels, dpi);
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
) async {
  // mm → 인치 → 픽셀: dpi=75 기준 1mm ≈ 2.95px
  final pxPerMm = dpi / 25.4;
  final widthPx = (sheet.sheetLength * pxPerMm).round();
  final heightPx = (sheet.sheetWidth * pxPerMm).round();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(widthPx.toDouble(), heightPx.toDouble());

  _PaintAdapter(
    canvas: canvas,
    size: size,
    sheet: sheet,
    stock: stock,
    showLabels: showLabels,
  ).paint();

  final picture = recorder.endRecording();
  final image = await picture.toImage(widthPx, heightPx);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

class _PaintAdapter {
  _PaintAdapter({
    required this.canvas,
    required this.size,
    required this.sheet,
    required this.stock,
    required this.showLabels,
  });
  final Canvas canvas;
  final Size size;
  final SheetLayout sheet;
  final StockSheet? stock;
  final bool showLabels;

  void paint() {
    final scaleX = size.width / sheet.sheetLength;
    final scaleY = size.height / sheet.sheetWidth;

    // 시트 배경: 자재 색 tint
    final stockColor = stock != null
        ? resolveColor(stock!.id, stock!.colorArgb, ColorPalette.stock)
        : const Color(0xFFF5F5F7);
    final bgColor = Color.lerp(Colors.white, stockColor, 0.35) ?? stockColor;
    canvas.drawRect(Offset.zero & size, Paint()..color = bgColor);

    // 시트 외곽
    final borderColor = stockColor.computeLuminance() < 0.7
        ? stockColor
        : const Color(0xFFE5E5E5);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    for (final pp in sheet.placed) {
      final rect = Rect.fromLTWH(
        pp.x * scaleX,
        pp.y * scaleY,
        pp.drawLength * scaleX,
        pp.drawWidth * scaleY,
      );
      final color = resolveColor(
        pp.part.id,
        pp.part.colorArgb,
        ColorPalette.part,
      );
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.45));
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      if (showLabels) {
        final dimText =
            '${pp.drawLength.toStringAsFixed(0)}×${pp.drawWidth.toStringAsFixed(0)}';
        final fullLabel = pp.part.label.isNotEmpty
            ? '${pp.part.label}\n$dimText'
            : dimText;
        final textColor = color.computeLuminance() < 0.5
            ? Colors.white
            : const Color(0xFF1A1A1A);
        final tp = TextPainter(
          text: TextSpan(
            text: fullLabel,
            style: TextStyle(color: textColor, fontSize: 10),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: rect.width);
        if (tp.height < rect.height && tp.width < rect.width) {
          tp.paint(
            canvas,
            Offset(
              rect.left + (rect.width - tp.width) / 2,
              rect.top + (rect.height - tp.height) / 2,
            ),
          );
        }
      }
    }
  }
}
