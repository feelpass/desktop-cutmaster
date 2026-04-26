import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/cutting_plan.dart';
import '../../domain/models/stock_sheet.dart';
import 'part_color.dart';

/// 시트 한 장(자재 배경 + 배치된 부품 + 선택적 라벨 + 선택적 헤더 텍스트)을
/// 주어진 [Canvas]에 그리는 순수 painter.
///
/// I/O 없음, 위젯 트리 의존 없음, Riverpod 의존 없음 — `png_export.dart`와
/// `cutting_canvas.dart`(live canvas)에서 모두 동일하게 호출.
///
/// 자재/부품 시각 구분 강화 포인트:
/// - 자재 배경 lerp 0.20 (옅은 tint — 부품 색이 묻히지 않게)
/// - 자재 외곽 2중선: stock 색 2.5px 바깥 + 흰색 1px 안쪽 halo (시트 경계 선명)
/// - 부품 fill alpha 0.60, stroke 1.8px (더 진하게)
/// - 라벨에 흰색 outline (가독성 — 반투명 fill 위에서 글자가 묻히지 않음)
class SheetPainter {
  SheetPainter({
    required this.sheet,
    required this.stock,
    required this.showLabels,
    required this.colorLookup,
    this.headerText,
    this.headerHeightPx = 24,
  });

  final SheetLayout sheet;
  final StockSheet? stock;
  final bool showLabels;
  final int? Function(String? colorPresetId) colorLookup;

  /// 시트 위쪽 외부에 표시할 헤더 (자재 이름 / 치수 등). null이면 헤더 영역
  /// 자체를 비워둔다 — live canvas는 부모 위젯이 텍스트를 따로 보여주므로 null.
  final String? headerText;

  /// 헤더가 있을 때 캔버스 상단에 예약할 높이(px). PNG/PDF export에서는
  /// 32px 정도, live canvas는 0(헤더 없음).
  final double headerHeightPx;

  void paint(Canvas canvas, Size size) {
    final headerH = (headerText != null) ? headerHeightPx : 0.0;
    final sheetRect = Rect.fromLTWH(0, headerH, size.width, size.height - headerH);

    if (headerText != null) {
      _paintHeader(canvas, Rect.fromLTWH(0, 0, size.width, headerH));
    }
    _paintSheet(canvas, sheetRect);
  }

  void _paintHeader(Canvas canvas, Rect rect) {
    final tp = TextPainter(
      text: TextSpan(
        text: headerText,
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - 4);
    // 좌측 4px 들여쓰기, 하단 padding 4px (rect 바닥에서 텍스트 높이만큼 위로).
    final dy = rect.bottom - tp.height - 4;
    tp.paint(canvas, Offset(rect.left + 4, dy < rect.top ? rect.top : dy));
  }

  void _paintSheet(Canvas canvas, Rect rect) {
    final scaleX = rect.width / sheet.sheetLength;
    final scaleY = rect.height / sheet.sheetWidth;

    // 자재 색 (부품과 구분되는 목재/저채도 톤).
    final stockColor = stock != null
        ? resolveColor(
            stock!.id,
            colorLookup(stock!.colorPresetId),
            ColorPalette.stock,
          )
        : const Color(0xFFF5F5F7);

    // 1) 시트 배경: 자재 색을 흰색과 0.20 lerp — 옅은 tint (부품이 잘 보이도록).
    final bgColor = Color.lerp(Colors.white, stockColor, 0.20) ?? stockColor;
    canvas.drawRect(rect, Paint()..color = bgColor);

    // 2) 자재 외곽선 (이중) — 부품과 시트 경계를 명확히 분리.
    //   바깥쪽: stock 색 2.5px (너무 옅으면 fallback 회색).
    final outerBorderColor = stockColor.computeLuminance() < 0.7
        ? stockColor
        : const Color(0xFFE5E5E5);
    canvas.drawRect(
      rect,
      Paint()
        ..color = outerBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    //   안쪽: 흰색 1px halo — 외곽선 안쪽 2px 들여서 그림.
    //   (부품이 시트 가장자리에 닿아도 시트 외곽선이 명확히 보이도록.)
    final innerHalo = rect.deflate(2);
    if (innerHalo.width > 0 && innerHalo.height > 0) {
      canvas.drawRect(
        innerHalo,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // 3) 부품들.
    for (final pp in sheet.placed) {
      final partRect = Rect.fromLTWH(
        rect.left + pp.x * scaleX,
        rect.top + pp.y * scaleY,
        pp.drawLength * scaleX,
        pp.drawWidth * scaleY,
      );
      final color = resolveColor(
        pp.part.id,
        colorLookup(pp.part.colorPresetId),
        ColorPalette.part,
      );
      // fill: 0.60 alpha (이전 0.45보다 진함).
      canvas.drawRect(partRect, Paint()..color = color.withValues(alpha: 0.60));
      // stroke: 1.8px (이전 1.2px보다 굵음).
      canvas.drawRect(
        partRect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

      if (showLabels) {
        _paintPartLabel(canvas, partRect, pp, color);
      }
    }
  }

  /// 부품 라벨 표시 — 위쪽 가운데에 가로 변 치수, 왼쪽 가운데에 세로 변 치수
  /// (90° 회전), 정중앙에 부품 이름. 부품 이름은 부품의 긴쪽 방향에 맞춰
  /// 회전된다 (가로형이면 가로, 세로형이면 90° 회전).
  void _paintPartLabel(Canvas canvas, Rect rect, PlacedPart pp, Color color) {
    final drawL = pp.drawLength;
    final drawW = pp.drawWidth;

    // 부품 색이 어두우면 흰 글자, 밝으면 검정 글자 — 자동 대비.
    final textColor = color.computeLuminance() < 0.5
        ? Colors.white
        : const Color(0xFF1A1A1A);

    const dimFontSize = 13.0;
    const nameFontSize = 14.0;

    // 위쪽 가운데: 가로 변 길이 (drawLength).
    _drawCenteredText(
      canvas,
      drawL.toStringAsFixed(0),
      anchor: Offset(rect.left + rect.width / 2, rect.top + 4),
      align: _TextAnchor.topCenter,
      maxWidth: rect.width - 8,
      fontSize: dimFontSize,
      textColor: textColor,
    );

    // 왼쪽 가운데: 세로 변 길이 (drawWidth), 90° 회전 (위→아래로 읽힘).
    canvas.save();
    canvas.translate(rect.left + 4, rect.top + rect.height / 2);
    canvas.rotate(-math.pi / 2);
    _drawCenteredText(
      canvas,
      drawW.toStringAsFixed(0),
      anchor: Offset.zero,
      align: _TextAnchor.topCenter,
      maxWidth: rect.height - 8,
      fontSize: dimFontSize,
      textColor: textColor,
    );
    canvas.restore();

    // 정중앙: 라벨 (이름). 부품의 긴쪽 방향으로 회전.
    if (pp.part.label.isNotEmpty) {
      final isHorizontal = drawL >= drawW;
      if (isHorizontal) {
        _drawCenteredText(
          canvas,
          pp.part.label,
          anchor: Offset(rect.left + rect.width / 2, rect.top + rect.height / 2),
          align: _TextAnchor.middleCenter,
          maxWidth: rect.width - 8,
          fontSize: nameFontSize,
          textColor: textColor,
        );
      } else {
        canvas.save();
        canvas.translate(
          rect.left + rect.width / 2,
          rect.top + rect.height / 2,
        );
        canvas.rotate(-math.pi / 2);
        _drawCenteredText(
          canvas,
          pp.part.label,
          anchor: Offset.zero,
          align: _TextAnchor.middleCenter,
          maxWidth: rect.height - 8,
          fontSize: nameFontSize,
          textColor: textColor,
        );
        canvas.restore();
      }
    }
  }

  /// 흰색 outline + 본 글자 두 패스로 그린다 (TextPainter가 stroke를 직접
  /// 지원하지 않으므로 foreground Paint(stroke)로 outline을 만든다).
  /// [anchor]는 텍스트 박스의 정렬 기준점, [align]은 그 점이 박스의 어디인지.
  void _drawCenteredText(
    Canvas canvas,
    String text, {
    required Offset anchor,
    required _TextAnchor align,
    required double maxWidth,
    required double fontSize,
    required Color textColor,
  }) {
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.white;
    final outlineTp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          foreground: outlinePaint,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final fillTp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    if (fillTp.width > maxWidth) return; // 안 들어가면 skip
    final dx = switch (align) {
      _TextAnchor.topCenter => anchor.dx - fillTp.width / 2,
      _TextAnchor.middleCenter => anchor.dx - fillTp.width / 2,
    };
    final dy = switch (align) {
      _TextAnchor.topCenter => anchor.dy,
      _TextAnchor.middleCenter => anchor.dy - fillTp.height / 2,
    };
    outlineTp.paint(canvas, Offset(dx, dy));
    fillTp.paint(canvas, Offset(dx, dy));
  }
}

enum _TextAnchor { topCenter, middleCenter }
