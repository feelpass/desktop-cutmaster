import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cutting_plan.dart';
import '../../domain/models/stock_sheet.dart';
import '../providers/preset_provider.dart';
import '../theme/app_colors.dart';
import '../utils/part_color.dart';

/// 시트 한 장의 재단 도면.
///
/// `maxSheetLength`가 주어지면 시트들 사이의 상대 크기를 유지.
/// 가장 긴 시트는 화면 너비를 가득 채우고, 짧은 시트는 비율에 맞춰 좁아짐.
/// `maxSheetLength`가 null이면 자기 폭을 가득 채움 (단일 시트일 때 유용).
///
/// 자재 색상을 시트 배경 tint로, 부품 색상은 자기 색으로 그려서 시각 층 구분.
class CuttingCanvas extends ConsumerWidget {
  const CuttingCanvas({
    super.key,
    required this.sheet,
    required this.stock,
    required this.showLabels,
    this.maxSheetLength,
  });

  final SheetLayout sheet;
  final StockSheet? stock;
  final bool showLabels;
  final double? maxSheetLength;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);
    int? lookup(String? id) =>
        id == null ? null : presets.colorById(id)?.argb;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // available width = 부모로부터 받은 max width
        final available = constraints.maxWidth;
        final widthFraction = (maxSheetLength == null || maxSheetLength == 0)
            ? 1.0
            : (sheet.sheetLength / maxSheetLength!).clamp(0.0, 1.0);
        final canvasWidth = available * widthFraction;
        final canvasHeight =
            canvasWidth * (sheet.sheetWidth / sheet.sheetLength);

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: CustomPaint(
              painter: _CuttingPainter(
                sheet: sheet,
                stock: stock,
                showLabels: showLabels,
                colorLookup: lookup,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CuttingPainter extends CustomPainter {
  _CuttingPainter({
    required this.sheet,
    required this.stock,
    required this.showLabels,
    required this.colorLookup,
  });

  final SheetLayout sheet;
  final StockSheet? stock;
  final bool showLabels;
  final int? Function(String? colorPresetId) colorLookup;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / sheet.sheetLength;
    final scaleY = size.height / sheet.sheetWidth;

    // 시트 배경: 자재 색상의 옅은 tint (자재 식별, 부품 가독성 유지).
    final stockColor = stock != null
        ? resolveColor(
            stock!.id,
            colorLookup(stock!.colorPresetId),
            ColorPalette.stock,
          )
        : AppColors.surface;
    final bgColor = Color.lerp(Colors.white, stockColor, 0.35) ?? stockColor;
    canvas.drawRect(Offset.zero & size, Paint()..color = bgColor);

    // 시트 외곽 (자재 색상이 짙으면 그 색으로, 옅으면 default border)
    final borderColor = stockColor.computeLuminance() < 0.7
        ? stockColor
        : AppColors.border;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 부품 그리기 — 각 부품의 색상 사용
    for (final pp in sheet.placed) {
      final rect = Rect.fromLTWH(
        pp.x * scaleX,
        pp.y * scaleY,
        pp.drawLength * scaleX,
        pp.drawWidth * scaleY,
      );
      final color = resolveColor(
        pp.part.id,
        colorLookup(pp.part.colorPresetId),
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
        // 부품 색이 어두우면 흰 글자, 밝으면 검정 글자
        final textColor = color.computeLuminance() < 0.5
            ? Colors.white
            : AppColors.textPrimary;
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

  @override
  bool shouldRepaint(covariant _CuttingPainter old) =>
      old.sheet != sheet ||
      old.stock != stock ||
      old.showLabels != showLabels;
}
