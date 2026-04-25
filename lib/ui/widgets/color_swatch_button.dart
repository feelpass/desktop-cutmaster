import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/part_color.dart';
import 'color_picker_dialog.dart';

/// 부품/자재 행에 들어가는 작은 색상 swatch 버튼.
/// 클릭하면 색상 picker 다이얼로그 열림.
class ColorSwatchButton extends StatelessWidget {
  const ColorSwatchButton({
    super.key,
    required this.entityId,
    required this.colorArgb,
    required this.palette,
    required this.onChanged,
  });

  final String entityId;
  final int? colorArgb;
  final ColorPalette palette;

  /// null = "자동" 선택, int = 특정 색상.
  final void Function(int? newArgb) onChanged;

  @override
  Widget build(BuildContext context) {
    final color = resolveColor(entityId, colorArgb, palette);
    final isAuto = colorArgb == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () async {
          final result = await showColorPickerDialog(
            context,
            currentArgb: colorArgb,
            palette: palette,
          );
          if (result == null) return;
          onChanged(result.argb);
        },
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isAuto ? AppColors.border : AppColors.textPrimary,
              width: isAuto ? 1 : 1.5,
            ),
          ),
          // 자동이면 작은 점 표시 (사용자가 명시 안 했음을 hint)
          child: isAuto
              ? Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color.computeLuminance() > 0.5
                          ? AppColors.textSecondary
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
