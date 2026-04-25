import 'package:flutter/material.dart';

import '../../domain/models/cutting_plan.dart';
import '../theme/app_colors.dart';

/// 시트 한 장의 재단 도면을 그리는 CustomPainter.
/// 시트 비율 유지하며 화면에 맞춰 scale.
class CuttingCanvas extends StatelessWidget {
  const CuttingCanvas({
    super.key,
    required this.sheet,
    required this.showLabels,
  });

  final SheetLayout sheet;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: sheet.sheetLength / sheet.sheetWidth,
      child: CustomPaint(
        painter: _CuttingPainter(sheet: sheet, showLabels: showLabels),
      ),
    );
  }
}

class _CuttingPainter extends CustomPainter {
  _CuttingPainter({required this.sheet, required this.showLabels});

  final SheetLayout sheet;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / sheet.sheetLength;
    final scaleY = size.height / sheet.sheetWidth;

    // 시트 배경
    final bg = Paint()..color = AppColors.surface;
    canvas.drawRect(Offset.zero & size, bg);

    // 시트 외곽
    final border = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Offset.zero & size, border);

    // 부품 그리기
    final partFill = Paint()..color = AppColors.primary.withValues(alpha: 0.15);
    final partStroke = Paint()
      ..color = AppColors.primary
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
        final dimText = '${pp.drawLength.toStringAsFixed(0)}×${pp.drawWidth.toStringAsFixed(0)}';
        final fullLabel = pp.part.label.isNotEmpty
            ? '${pp.part.label}\n$dimText'
            : dimText;
        final tp = TextPainter(
          text: TextSpan(
            text: fullLabel,
            style: const TextStyle(
              color: AppColors.textPrimary,
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

  @override
  bool shouldRepaint(covariant _CuttingPainter old) =>
      old.sheet != sheet || old.showLabels != showLabels;
}
