import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/part_color.dart';

/// 색상 선택 다이얼로그. 팔레트(part/stock)별로 다른 프리셋 표시.
/// 결과:
///   - null: 사용자가 다이얼로그 닫음 (변경 없음)
///   - ColorChoice.auto: "자동" 선택 (colorArgb = null로 저장)
///   - ColorChoice.value(argb): 특정 색상 선택
Future<ColorChoice?> showColorPickerDialog(
  BuildContext context, {
  required int? currentArgb,
  required ColorPalette palette,
}) {
  final presets = presetsFor(palette);
  final isPart = palette == ColorPalette.part;
  return showDialog<ColorChoice>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(isPart ? '부품 색상 선택' : '자재 색상 선택'),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 자동 옵션
              InkWell(
                onTap: () => Navigator.pop(ctx, ColorChoice.auto),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isPart
                                ? const [Color(0xFFEF4444), Color(0xFF8B5CF6)]
                                : const [Color(0xFFE8D2A6), Color(0xFF6B6B6B)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: currentArgb == null
                                ? AppColors.primary
                                : AppColors.border,
                            width: currentArgb == null ? 2 : 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(isPart ? '자동 (부품 ID 기반)' : '자동 (자재 ID 기반)'),
                    ],
                  ),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                isPart ? '부품 색상' : '재질 색상',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              // 프리셋 그리드
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((p) {
                  final isSelected = currentArgb == p.color.toARGB32();
                  // 밝은 색은 border 더 진하게
                  final isVeryLight = p.color.computeLuminance() > 0.85;
                  return InkWell(
                    onTap: () => Navigator.pop(
                      ctx,
                      ColorChoice.value(p.color.toARGB32()),
                    ),
                    child: Tooltip(
                      message: p.name,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: p.color,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.textPrimary
                                : (isVeryLight
                                    ? AppColors.tableHeaderText
                                    : AppColors.border),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      );
    },
  );
}

class ColorChoice {
  final int? argb;
  const ColorChoice._(this.argb);
  static const auto = ColorChoice._(null);
  factory ColorChoice.value(int argb) => ColorChoice._(argb);
}
