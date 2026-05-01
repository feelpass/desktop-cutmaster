import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/preset_provider.dart';
import '../theme/app_colors.dart';
import '../utils/part_color.dart';
import 'color_picker_dialog.dart';

/// 부품/자재 행에 들어가는 작은 색상 swatch 버튼.
/// 클릭하면 색상 picker 다이얼로그 열림.
///
/// [colorPresetId]는 ColorPreset.id 참조. null이면 "자동" — ID 해시 기반 색.
/// onChanged는 picker 결과의 colorPresetId(String?)를 그대로 전달한다.
class ColorSwatchButton extends ConsumerWidget {
  const ColorSwatchButton({
    super.key,
    required this.entityId,
    required this.colorPresetId,
    required this.palette,
    required this.onChanged,
  });

  final String entityId;
  final String? colorPresetId;
  final ColorPalette palette;

  /// null = "자동" 선택, String = 특정 색상 프리셋 id.
  final void Function(String? newPresetId) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);
    final argb = colorPresetId == null
        ? null
        : presets.colorById(colorPresetId)?.argb;
    final color = resolveColor(entityId, argb, palette);
    final isAuto = argb == null;
    final pal = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () async {
          final result = await showColorPickerDialog(
            context,
            currentPresetId: colorPresetId,
          );
          if (result == null) return;
          onChanged(result.presetId);
        },
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isAuto ? pal.border : pal.textPrimary,
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
                          ? pal.textSecondary
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
