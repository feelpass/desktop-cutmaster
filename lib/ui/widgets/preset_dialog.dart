import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preset/preset_models.dart';
import '../../domain/models/cut_part.dart';
import '../../domain/models/stock_sheet.dart';
import '../providers/preset_provider.dart';
import '../theme/app_colors.dart';
import 'preset_management_dialog.dart' show PresetKind, showPresetManagementDialog;

/// 부품/자재 프리셋 선택 다이얼로그를 띄우고 사용자가 고른 프리셋으로부터 만든
/// 새 [CutPart] (kind == part) 또는 [StockSheet] (kind == stock)을 반환한다.
/// qty는 1, id는 새로 생성, 나머지 필드(label/length/width/colorPresetId/
/// grainDirection)는 [DimensionPreset]에서 복사. 사용자가 닫으면 null.
Future<dynamic> showPresetDialog(BuildContext context, PresetKind kind) {
  return showDialog<dynamic>(
    context: context,
    builder: (_) => _PresetSelectorDialog(kind: kind),
  );
}

class _PresetSelectorDialog extends ConsumerWidget {
  const _PresetSelectorDialog({required this.kind});

  final PresetKind kind;

  String get _title =>
      kind == PresetKind.part ? '부품 프리셋 선택' : '자재 프리셋 선택';

  List<DimensionPreset> _collection(PresetsNotifier n) =>
      kind == PresetKind.part ? n.state.parts : n.state.stocks;

  /// 선택된 프리셋으로 fresh 모델(qty=1, 새 id)을 만들어 반환.
  dynamic _materialize(DimensionPreset p) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    if (kind == PresetKind.part) {
      return CutPart(
        id: 'p_$ts',
        length: p.length,
        width: p.width,
        qty: 1,
        label: p.label,
        colorPresetId: p.colorPresetId,
        grainDirection: p.grainDirection,
      );
    }
    return StockSheet(
      id: 's_$ts',
      length: p.length,
      width: p.width,
      qty: 1,
      label: p.label,
      colorPresetId: p.colorPresetId,
      grainDirection: p.grainDirection,
    );
  }

  /// 정수면 정수로 — 치수 표시 포맷.
  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(presetsProvider);
    final list = _collection(notifier);

    return AlertDialog(
      title: Text(_title),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 360,
        child: list.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text(
                  '아직 등록된 프리셋이 없습니다. 아래 "프리셋 관리..."로 추가하세요.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in list)
                      InkWell(
                        onTap: () =>
                            Navigator.of(context).pop(_materialize(p)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${_fmt(p.length)} × ${_fmt(p.width)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => showPresetManagementDialog(context, kind),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('프리셋 관리...'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        ),
      ],
    );
  }
}
