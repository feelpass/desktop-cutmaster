import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preset/preset_models.dart';
import '../../domain/models/stock_sheet.dart' show GrainDirection;
import '../providers/preset_provider.dart';
import '../theme/app_colors.dart';
import 'color_picker_dialog.dart';

/// 부품 또는 자재 프리셋 — 동일한 다이얼로그가 [kind]에 따라 라우팅된다.
enum PresetKind { part, stock }

/// 부품/자재 프리셋 관리 다이얼로그 헬퍼.
Future<void> showPresetManagementDialog(
  BuildContext context,
  PresetKind kind,
) =>
    showDialog<void>(
      context: context,
      builder: (_) => PresetManagementDialog(kind: kind),
    );

/// 좌측 리스트(label + swatch) + 우측 폼(label/length/width/color/grain) 형태의
/// DimensionPreset 관리 다이얼로그. [kind]에 따라 parts 또는 stocks 컬렉션을
/// 대상으로 동작한다.
class PresetManagementDialog extends ConsumerStatefulWidget {
  const PresetManagementDialog({super.key, required this.kind});

  final PresetKind kind;

  @override
  ConsumerState<PresetManagementDialog> createState() =>
      _PresetManagementDialogState();
}

class _PresetManagementDialogState
    extends ConsumerState<PresetManagementDialog> {
  String? _selectedId;

  // 텍스트 컨트롤러들 — 디바운스 + dispose flush 처리.
  final TextEditingController _labelCtrl = TextEditingController();
  final TextEditingController _lengthCtrl = TextEditingController();
  final TextEditingController _widthCtrl = TextEditingController();

  Timer? _saveTimer;
  String? _ctrlBoundId;

  // 보류 중인(아직 디바운스 미발화) 변경 — dispose flush용.
  String? _pendingLabel;
  String? _pendingLength;
  String? _pendingWidth;
  String? _pendingId;

  @override
  void dispose() {
    // dispose 직전 보류 중인 저장이 있으면 즉시 flush.
    _saveTimer?.cancel();
    final pendingId = _pendingId;
    if (pendingId != null) {
      final notifier = ref.read(presetsProvider);
      final current = _findById(_collection(notifier), pendingId);
      if (current != null) {
        final next = _applyPendingTo(current);
        if (next != current) {
          _persistUpdate(notifier, next);
        }
      }
    }
    _labelCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    super.dispose();
  }

  // ── kind 라우팅 헬퍼들 ─────────────────────────────────────────────

  String get _title =>
      widget.kind == PresetKind.part ? '부품 프리셋 관리' : '자재 프리셋 관리';

  String get _idPrefix => widget.kind == PresetKind.part ? 'pp_' : 'sp_';

  String get _newLabel =>
      widget.kind == PresetKind.part ? '새 부품 프리셋' : '새 자재 프리셋';

  List<DimensionPreset> _collection(PresetsNotifier n) =>
      widget.kind == PresetKind.part ? n.state.parts : n.state.stocks;

  Future<void> _persistUpdate(PresetsNotifier n, DimensionPreset d) =>
      widget.kind == PresetKind.part
          ? n.updatePartPreset(d)
          : n.updateStockPreset(d);

  Future<void> _persistAdd(PresetsNotifier n, DimensionPreset d) =>
      widget.kind == PresetKind.part
          ? n.addPartPreset(d)
          : n.addStockPreset(d);

  Future<void> _persistRemove(PresetsNotifier n, String id) =>
      widget.kind == PresetKind.part
          ? n.removePartPreset(id)
          : n.removeStockPreset(id);

  // ── 헬퍼 ───────────────────────────────────────────────────────────

  DimensionPreset? _findById(List<DimensionPreset> list, String id) {
    for (final d in list) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// 보류 중인 텍스트 변경을 [d]에 반영해 새로운 DimensionPreset을 만든다.
  /// dispose flush에서만 호출.
  DimensionPreset _applyPendingTo(DimensionPreset d) {
    var next = d;
    if (_pendingLabel != null && _pendingLabel != d.label) {
      next = next.copyWith(label: _pendingLabel);
    }
    if (_pendingLength != null) {
      final v = double.tryParse(_pendingLength!);
      if (v != null && v != d.length) next = next.copyWith(length: v);
    }
    if (_pendingWidth != null) {
      final v = double.tryParse(_pendingWidth!);
      if (v != null && v != d.width) next = next.copyWith(width: v);
    }
    return next;
  }

  /// 선택이 바뀌면 텍스트 컨트롤러들을 그 프리셋 값으로 동기화한다.
  void _syncControllersForSelection(DimensionPreset? selected) {
    final id = selected?.id;
    if (_ctrlBoundId == id) return;
    _ctrlBoundId = id;
    _saveTimer?.cancel();
    _pendingLabel = null;
    _pendingLength = null;
    _pendingWidth = null;
    _pendingId = null;
    _labelCtrl.text = selected?.label ?? '';
    _lengthCtrl.text = selected == null ? '' : _fmt(selected.length);
    _widthCtrl.text = selected == null ? '' : _fmt(selected.width);
  }

  /// 정수면 정수로, 아니면 소수점 그대로 — 길이/폭 표시 포맷.
  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// 텍스트 필드 변경 — 디바운스 후 persist.
  void _scheduleSave(DimensionPreset selected) {
    _pendingId = selected.id;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final notifier = ref.read(presetsProvider);
      final current = _findById(_collection(notifier), selected.id);
      if (current == null) return;
      final next = _applyPendingTo(current);
      if (next == current) return;
      _persistUpdate(notifier, next);
    });
  }

  void _onLabelChanged(String v, DimensionPreset selected) {
    _pendingLabel = v;
    _scheduleSave(selected);
  }

  void _onLengthChanged(String v, DimensionPreset selected) {
    _pendingLength = v;
    _scheduleSave(selected);
  }

  void _onWidthChanged(String v, DimensionPreset selected) {
    _pendingWidth = v;
    _scheduleSave(selected);
  }

  Future<void> _addNew() async {
    final notifier = ref.read(presetsProvider);
    final id = '$_idPrefix${DateTime.now().microsecondsSinceEpoch}';
    final defaults = widget.kind == PresetKind.part
        ? const _Defaults(length: 600, width: 300)
        : const _Defaults(length: 2440, width: 1220);
    final fresh = DimensionPreset(
      id: id,
      label: _newLabel,
      length: defaults.length,
      width: defaults.width,
      colorPresetId: null,
      grainDirection: GrainDirection.none,
    );
    await _persistAdd(notifier, fresh);
    if (!mounted) return;
    setState(() => _selectedId = id);
  }

  Future<void> _confirmDelete(DimensionPreset selected) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text('"${selected.label}" 프리셋을 삭제하시겠습니까?'),
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
    await _persistRemove(ref.read(presetsProvider), selected.id);
    if (!mounted) return;
    setState(() => _selectedId = null);
  }

  Future<void> _pickColor(DimensionPreset selected) async {
    final choice = await showColorPickerDialog(
      context,
      currentPresetId: selected.colorPresetId,
    );
    if (choice == null) return;
    if (!mounted) return;
    final notifier = ref.read(presetsProvider);
    final current = _findById(_collection(notifier), selected.id);
    if (current == null) return;
    final next = choice.presetId == null
        ? current.copyWith(clearColor: true)
        : current.copyWith(colorPresetId: choice.presetId);
    if (next == current) return;
    await _persistUpdate(notifier, next);
  }

  Future<void> _onGrainChanged(
    DimensionPreset selected,
    GrainDirection g,
  ) async {
    if (selected.grainDirection == g) return;
    final notifier = ref.read(presetsProvider);
    final current = _findById(_collection(notifier), selected.id);
    if (current == null) return;
    await _persistUpdate(notifier, current.copyWith(grainDirection: g));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(presetsProvider);
    final list = _collection(notifier);
    final selected =
        _selectedId == null ? null : _findById(list, _selectedId!);

    _syncControllersForSelection(selected);

    return AlertDialog(
      title: Text(_title),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 580,
        height: 440,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // === 좌측: 리스트 + 추가 버튼 ===
            SizedBox(
              width: 220,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final d in list)
                              _PresetRow(
                                preset: d,
                                selected: d.id == _selectedId,
                                colorPreset: notifier.colorById(d.colorPresetId),
                                onTap: () =>
                                    setState(() => _selectedId = d.id),
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
            Expanded(
              child: selected == null
                  ? const Center(
                      child: Text(
                        '왼쪽에서 프리셋을 선택하세요',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : _PresetForm(
                      preset: selected,
                      colorPreset:
                          notifier.colorById(selected.colorPresetId),
                      labelCtrl: _labelCtrl,
                      lengthCtrl: _lengthCtrl,
                      widthCtrl: _widthCtrl,
                      onLabelChanged: (v) => _onLabelChanged(v, selected),
                      onLengthChanged: (v) => _onLengthChanged(v, selected),
                      onWidthChanged: (v) => _onWidthChanged(v, selected),
                      onPickColor: () => _pickColor(selected),
                      onGrainChanged: (g) => _onGrainChanged(selected, g),
                      onDelete: () => _confirmDelete(selected),
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

class _Defaults {
  final double length;
  final double width;
  const _Defaults({required this.length, required this.width});
}

/// 좌측 리스트의 한 행 — label + 작은 swatch.
class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.preset,
    required this.selected,
    required this.colorPreset,
    required this.onTap,
  });

  final DimensionPreset preset;
  final bool selected;
  final ColorPreset? colorPreset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : null,
        child: Row(
          children: [
            _Swatch(colorPreset: colorPreset),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                preset.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 작은 색상 칩. colorPreset이 null이면 "자동" 그라디언트.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.colorPreset});
  final ColorPreset? colorPreset;

  @override
  Widget build(BuildContext context) {
    if (colorPreset == null) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppColors.border),
        ),
      );
    }
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Color(colorPreset!.argb),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

/// 우측 폼 — 라벨/길이/폭/색상/결방향/삭제.
class _PresetForm extends StatelessWidget {
  const _PresetForm({
    required this.preset,
    required this.colorPreset,
    required this.labelCtrl,
    required this.lengthCtrl,
    required this.widthCtrl,
    required this.onLabelChanged,
    required this.onLengthChanged,
    required this.onWidthChanged,
    required this.onPickColor,
    required this.onGrainChanged,
    required this.onDelete,
  });

  final DimensionPreset preset;
  final ColorPreset? colorPreset;
  final TextEditingController labelCtrl;
  final TextEditingController lengthCtrl;
  final TextEditingController widthCtrl;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<String> onLengthChanged;
  final ValueChanged<String> onWidthChanged;
  final VoidCallback onPickColor;
  final ValueChanged<GrainDirection> onGrainChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('라벨'),
        const SizedBox(height: 4),
        TextField(
          controller: labelCtrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onLabelChanged,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('길이'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: lengthCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: onLengthChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('폭'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: widthCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: onWidthChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _FieldLabel('색상'),
        const SizedBox(height: 4),
        OutlinedButton(
          onPressed: onPickColor,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Swatch(colorPreset: colorPreset),
              const SizedBox(width: 8),
              Text(colorPreset?.name ?? '자동'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _FieldLabel('결방향'),
        const SizedBox(height: 4),
        SegmentedButton<GrainDirection>(
          segments: const [
            ButtonSegment(
              value: GrainDirection.lengthwise,
              label: Text('가로결'),
              icon: Icon(Icons.swap_horiz),
            ),
            ButtonSegment(
              value: GrainDirection.widthwise,
              label: Text('세로결'),
              icon: Icon(Icons.swap_vert),
            ),
            ButtonSegment(
              value: GrainDirection.none,
              label: Text('무관'),
              icon: Icon(Icons.remove),
            ),
          ],
          selected: {preset.grainDirection},
          onSelectionChanged: (s) => onGrainChanged(s.first),
          showSelectedIcon: false,
        ),
        const Spacer(),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('삭제'),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      );
}
