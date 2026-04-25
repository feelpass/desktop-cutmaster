import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/models/cutting_plan.dart';

/// 시트별 PNG 파일 저장. 기본 75dpi (메모리 압박 방지).
/// 큰 시트(2440×1220)도 75dpi면 ~7200×3600px 정도, raw ~100MB.
/// 너무 크면 60dpi로 fallback 가능.
Future<void> exportSheetsToPng(
  BuildContext context,
  CuttingPlan plan,
  bool showLabels, {
  double dpi = 75,
}) async {
  final dir = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'PNG 저장 위치 선택',
  );
  if (dir == null) return;

  for (int i = 0; i < plan.sheets.length; i++) {
    final s = plan.sheets[i];
    final png = await _renderSheetToPng(s, showLabels, dpi);
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

  // CustomPainter 직접 호출 대신, 같은 그리기 로직 _PaintAdapter로 분리해 재사용.
  // (Widget tree 없이 픽셀 단위로 정확히 렌더링.)
  _PaintAdapter(
    canvas: canvas,
    size: size,
    sheet: sheet,
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
    required this.showLabels,
  });
  final Canvas canvas;
  final Size size;
  final SheetLayout sheet;
  final bool showLabels;

  void paint() {
    final scaleX = size.width / sheet.sheetLength;
    final scaleY = size.height / sheet.sheetWidth;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF5F5F7),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFFE5E5E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final partFill =
        Paint()..color = const Color(0xFF16A34A).withValues(alpha: 0.15);
    final partStroke = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final pp in sheet.placed) {
      final rect = Rect.fromLTWH(
        pp.x * scaleX,
        pp.y * scaleY,
        pp.drawLength * scaleX,
        pp.drawWidth * scaleY,
      );
      canvas.drawRect(rect, partFill);
      canvas.drawRect(rect, partStroke);

      if (showLabels) {
        final dimText =
            '${pp.drawLength.toStringAsFixed(0)}×${pp.drawWidth.toStringAsFixed(0)}';
        final fullLabel = pp.part.label.isNotEmpty
            ? '${pp.part.label}\n$dimText'
            : dimText;
        final tp = TextPainter(
          text: TextSpan(
            text: fullLabel,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 10,
            ),
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
