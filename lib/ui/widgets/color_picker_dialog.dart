import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/preset_provider.dart';
import '../theme/app_colors.dart';
import 'color_preset_management_dialog.dart';

/// 글로벌 색상 프리셋 선택 다이얼로그.
/// 결과:
///   - null                          : 사용자가 다이얼로그 닫음 (변경 없음)
///   - ColorChoice.auto              : "자동" 선택 (colorPresetId = null로 저장)
///   - ColorChoice.value(presetId)   : 선택된 색상 프리셋 id
Future<ColorChoice?> showColorPickerDialog(
  BuildContext context, {
  required String? currentPresetId,
}) {
  return showDialog<ColorChoice>(
    context: context,
    builder: (ctx) => _ColorPickerDialog(currentPresetId: currentPresetId),
  );
}

class _ColorPickerDialog extends ConsumerWidget {
  const _ColorPickerDialog({required this.currentPresetId});

  final String? currentPresetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(presetsProvider);
    final colors = presets.state.colors;
    final pal = context.colors;
    return AlertDialog(
      title: const Text('색상 선택'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 자동 옵션
              InkWell(
                onTap: () => Navigator.pop(context, ColorChoice.auto),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: currentPresetId == null
                                ? AppColors.primary
                                : pal.border,
                            width: currentPresetId == null ? 2 : 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('자동 (ID 기반)'),
                    ],
                  ),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '색상 프리셋',
                style: TextStyle(
                  fontSize: 11,
                  color: pal.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              // 프리셋 목록 (swatch + 이름)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((c) {
                  final isSelected = currentPresetId == c.id;
                  final color = Color(c.argb);
                  final isVeryLight = color.computeLuminance() > 0.85;
                  return InkWell(
                    onTap: () => Navigator.pop(
                      context,
                      ColorChoice.value(c.id),
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isSelected
                                    ? pal.textPrimary
                                    : (isVeryLight
                                        ? pal.tableHeaderText
                                        : pal.border),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Divider(),
              // 관리 entry — picker는 닫지 않고 management 다이얼로그를 그 위에 띄운다.
              TextButton.icon(
                onPressed: () => showColorPresetManagementDialog(context),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('색상 프리셋 관리...'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

class ColorChoice {
  final String? presetId;
  const ColorChoice._(this.presetId);
  static const auto = ColorChoice._(null);
  factory ColorChoice.value(String presetId) => ColorChoice._(presetId);
}
