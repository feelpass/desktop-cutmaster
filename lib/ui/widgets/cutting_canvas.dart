import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cutting_plan.dart';
import '../../domain/models/stock_sheet.dart';
import '../providers/preset_provider.dart';
import '../utils/sheet_painter.dart';

/// 시트 한 장의 재단 도면.
///
/// `maxSheetLength`가 주어지면 시트들 사이의 상대 크기를 유지.
/// 가장 긴 시트는 화면 너비를 가득 채우고, 짧은 시트는 비율에 맞춰 좁아짐.
/// `maxSheetLength`가 null이면 자기 폭을 가득 채움 (단일 시트일 때 유용).
///
/// 자재 색상을 시트 배경 tint로, 부품 색상은 자기 색으로 그려서 시각 층 구분.
/// 실제 painting은 [SheetPainter] (PNG export와 공유) 에 위임.
/// live canvas는 부모 위젯이 별도로 자재명/치수 텍스트를 보여주므로 헤더 없음.
class CuttingCanvas extends ConsumerWidget {
  const CuttingCanvas({
    super.key,
    required this.sheet,
    required this.stock,
    required this.showLabels,
    this.maxSheetLength,
    this.headcutTop = 0,
    this.headcutBottom = 0,
    this.headcutLeft = 0,
    this.headcutRight = 0,
  });

  final SheetLayout sheet;
  final StockSheet? stock;
  final bool showLabels;
  final double? maxSheetLength;
  final double headcutTop;
  final double headcutBottom;
  final double headcutLeft;
  final double headcutRight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);
    int? lookup(String? id) =>
        id == null ? null : presets.colorById(id)?.argb;

    return LayoutBuilder(
      builder: (ctx, constraints) {
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
                headcutTop: headcutTop,
                headcutBottom: headcutBottom,
                headcutLeft: headcutLeft,
                headcutRight: headcutRight,
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
    required this.headcutTop,
    required this.headcutBottom,
    required this.headcutLeft,
    required this.headcutRight,
  });

  final SheetLayout sheet;
  final StockSheet? stock;
  final bool showLabels;
  final int? Function(String? colorPresetId) colorLookup;
  final double headcutTop;
  final double headcutBottom;
  final double headcutLeft;
  final double headcutRight;

  @override
  void paint(Canvas canvas, Size size) {
    SheetPainter(
      sheet: sheet,
      stock: stock,
      showLabels: showLabels,
      colorLookup: colorLookup,
    ).paint(canvas, size);
    _paintHeadcut(canvas, size);
  }

  /// 헤드컷 영역에 빗금 음영을 그려 "잘려나갈 부분" 시각화.
  void _paintHeadcut(Canvas canvas, Size size) {
    if (sheet.sheetLength <= 0 || sheet.sheetWidth <= 0) return;
    final scaleX = size.width / sheet.sheetLength;
    final scaleY = size.height / sheet.sheetWidth;

    final fill = Paint()
      ..color = const Color(0x33EF4444) // semi-transparent red
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    void band(Rect r) {
      if (r.width <= 0 || r.height <= 0) return;
      canvas.drawRect(r, fill);
      canvas.drawRect(r, border);
    }

    if (headcutTop > 0) {
      band(Rect.fromLTWH(0, 0, size.width, headcutTop * scaleY));
    }
    if (headcutBottom > 0) {
      band(Rect.fromLTWH(
          0, size.height - headcutBottom * scaleY, size.width, headcutBottom * scaleY));
    }
    if (headcutLeft > 0) {
      band(Rect.fromLTWH(0, 0, headcutLeft * scaleX, size.height));
    }
    if (headcutRight > 0) {
      band(Rect.fromLTWH(size.width - headcutRight * scaleX, 0,
          headcutRight * scaleX, size.height));
    }
  }

  @override
  bool shouldRepaint(covariant _CuttingPainter old) =>
      old.sheet != sheet ||
      old.stock != stock ||
      old.showLabels != showLabels ||
      old.headcutTop != headcutTop ||
      old.headcutBottom != headcutBottom ||
      old.headcutLeft != headcutLeft ||
      old.headcutRight != headcutRight;
}
