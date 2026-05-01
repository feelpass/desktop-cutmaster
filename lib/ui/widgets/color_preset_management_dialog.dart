import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preset/preset_models.dart';
import '../providers/preset_provider.dart';
import '../theme/app_colors.dart';

/// 색상 프리셋 관리 다이얼로그를 띄우는 헬퍼.
Future<void> showColorPresetManagementDialog(BuildContext ctx) =>
    showDialog<void>(
      context: ctx,
      builder: (_) => const ColorPresetManagementDialog(),
    );

/// 좌측 리스트 + 우측 폼 레이아웃의 색상 프리셋 관리 다이얼로그.
///
/// - 좌측: 등록된 색상 프리셋 목록 + "추가" 버튼
/// - 우측: 선택된 프리셋의 이름/색상 편집 + 삭제 버튼
class ColorPresetManagementDialog extends ConsumerStatefulWidget {
  const ColorPresetManagementDialog({super.key});

  @override
  ConsumerState<ColorPresetManagementDialog> createState() =>
      _ColorPresetManagementDialogState();
}

class _ColorPresetManagementDialogState
    extends ConsumerState<ColorPresetManagementDialog> {
  String? _selectedId;
  final TextEditingController _nameCtrl = TextEditingController();
  Timer? _saveTimer;
  String? _ctrlBoundId;

  @override
  void dispose() {
    // dispose 직전 보류 중인 저장이 있으면 즉시 flush.
    _saveTimer?.cancel();
    final pending = _pendingName;
    final pendingId = _pendingId;
    if (pending != null && pendingId != null) {
      final notifier = ref.read(presetsProvider);
      final current = _findById(notifier.state.colors, pendingId);
      if (current != null && current.name != pending) {
        // fire-and-forget — widget은 이미 disposed 됨
        notifier.updateColor(current.copyWith(name: pending));
      }
    }
    _nameCtrl.dispose();
    super.dispose();
  }

  String? _pendingName;
  String? _pendingId;

  ColorPreset? _findById(List<ColorPreset> list, String id) {
    for (final c in list) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 선택이 바뀌면 텍스트 컨트롤러를 그 프리셋 이름으로 동기화한다.
  void _syncControllerForSelection(ColorPreset? selected) {
    final id = selected?.id;
    if (_ctrlBoundId == id) return;
    _ctrlBoundId = id;
    _saveTimer?.cancel();
    _pendingName = null;
    _pendingId = null;
    _nameCtrl.text = selected?.name ?? '';
    _nameCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _nameCtrl.text.length),
    );
  }

  void _onNameChanged(String v, ColorPreset selected) {
    _pendingName = v;
    _pendingId = selected.id;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final notifier = ref.read(presetsProvider);
      final current = _findById(notifier.state.colors, selected.id);
      if (current == null) return;
      if (current.name == v) return;
      notifier.updateColor(current.copyWith(name: v));
    });
  }

  Future<void> _addNew() async {
    final notifier = ref.read(presetsProvider);
    final id = 'cp_${DateTime.now().microsecondsSinceEpoch}';
    final fresh = ColorPreset(id: id, name: '새 색상', argb: 0xFF888888);
    await notifier.addColor(fresh);
    if (!mounted) return;
    setState(() {
      _selectedId = id;
    });
  }

  Future<void> _confirmDelete(ColorPreset selected) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(
          '"${selected.name}" 색상 프리셋을 삭제하시겠습니까?\n'
          '이 색상을 사용 중인 부품/자재 프리셋은 자동 색상으로 전환됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    await ref.read(presetsProvider).removeColor(selected.id);
    if (!mounted) return;
    setState(() {
      _selectedId = null;
    });
  }

  Future<void> _pickColor(ColorPreset selected) async {
    final picked = await _showColorPicker(context, selected.argb);
    if (picked == null) return;
    if (!mounted) return;
    final notifier = ref.read(presetsProvider);
    final current = _findById(notifier.state.colors, selected.id);
    if (current == null) return;
    await notifier.updateColor(current.copyWith(argb: picked));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(presetsProvider);
    final colors = notifier.state.colors;
    final selected =
        _selectedId == null ? null : _findById(colors, _selectedId!);

    // selected의 이름은 외부 변경 시 controller에도 반영.
    _syncControllerForSelection(selected);

    return AlertDialog(
      title: const Text('색상 프리셋 관리'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // === 좌측: 리스트 + 추가 버튼 ===
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: context.colors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final c in colors)
                              InkWell(
                                onTap: () =>
                                    setState(() => _selectedId = c.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  color: c.id == _selectedId
                                      ? AppColors.primary
                                          .withValues(alpha: 0.12)
                                      : null,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: Color(c.argb),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          border: Border.all(
                                              color: context.colors.border),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: c.id == _selectedId
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
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
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Tooltip(
                      message: '추가',
                      child: OutlinedButton.icon(
                        onPressed: _addNew,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('추가'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // === 우측: 폼 ===
            SizedBox(
              width: 280,
              child: selected == null
                  ? Center(
                      child: Text(
                        '왼쪽에서 색상을 선택하세요',
                        style:
                            TextStyle(color: context.colors.textSecondary),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이름',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => _onNameChanged(v, selected),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '색상',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _pickColor(selected),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(selected.argb),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: context.colors.border),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _confirmDelete(selected),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('삭제'),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

/// 색상 선택 서브 다이얼로그. 사용자가 "확인"을 누르면 ARGB int 반환.
Future<int?> _showColorPicker(BuildContext ctx, int initial) async {
  Color picked = Color(initial);
  return showDialog<int>(
    context: ctx,
    builder: (c) => AlertDialog(
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: Color(initial),
          onColorChanged: (col) => picked = col,
          enableAlpha: false,
          pickerAreaHeightPercent: 0.7,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(c, picked.toARGB32() | 0xFF000000),
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
