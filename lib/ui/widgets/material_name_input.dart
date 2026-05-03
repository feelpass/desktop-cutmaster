import 'package:flutter/material.dart';

import '../../data/preset/preset_models.dart';
import '../providers/preset_provider.dart';

/// 자재(색상) 이름을 텍스트로 입력하는 필드. 입력값 확정 시:
/// - 빈 문자열 → onChanged(null)
/// - 기존 프리셋 이름과 정확 일치 → 그 id로 onChanged
/// - 일치 없음 → presets.addColor 자동 생성 후 새 id로 onChanged
class MaterialNameInput extends StatefulWidget {
  final String? colorPresetId;
  final PresetsNotifier presets;
  final ValueChanged<String?> onChanged;
  final double? width;
  final String? hintText;

  const MaterialNameInput({
    super.key,
    required this.colorPresetId,
    required this.presets,
    required this.onChanged,
    this.width,
    this.hintText,
  });

  @override
  State<MaterialNameInput> createState() => _MaterialNameInputState();
}

class _MaterialNameInputState extends State<MaterialNameInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText());
    _focusNode = FocusNode();
  }

  String _initialText() {
    final id = widget.colorPresetId;
    if (id == null) return '';
    final match = widget.presets.colorById(id);
    return match?.name ?? '';
  }

  @override
  void didUpdateWidget(covariant MaterialNameInput old) {
    super.didUpdateWidget(old);
    if (old.colorPresetId != widget.colorPresetId) {
      final next = _initialText();
      if (_controller.text != next) {
        _controller.text = next;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _resolve(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final colors = widget.presets.state.colors;
    for (final c in colors) {
      if (c.name == trimmed) {
        widget.onChanged(c.id);
        return;
      }
    }
    final created = ColorPreset(
      id: 'cp_inline_${trimmed.hashCode.toUnsigned(16).toRadixString(16)}',
      name: trimmed,
      argb: _autoArgbForName(trimmed),
    );
    await widget.presets.addColor(created);
    widget.onChanged(created.id);
  }

  @override
  Widget build(BuildContext context) {
    final field = RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final q = value.text.trim().toLowerCase();
        final names = widget.presets.state.colors.map((c) => c.name).toList();
        if (q.isEmpty) return names;
        return names.where((n) => n.toLowerCase().contains(q));
      },
      onSelected: _resolve,
      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) =>
          TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hintText ?? '자재 이름',
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: const OutlineInputBorder(),
        ),
        onFieldSubmitted: (value) async {
          onFieldSubmitted();
          await _resolve(value);
        },
      ),
      optionsViewBuilder: (ctx, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(6),
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: 200, maxWidth: widget.width ?? 200),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (ctx, i) {
                final option = options.elementAt(i);
                return InkWell(
                  onTap: () => onSelected(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child:
                        Text(option, style: const TextStyle(fontSize: 13)),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: field);
    }
    return field;
  }
}

/// 행 leading의 색상 도트 클릭 시 자재 이름을 텍스트로 편집하는 다이얼로그.
/// 입력 확정 시 [onChanged]에 새 colorPresetId(자동 생성 포함)를 전달하고
/// 다이얼로그를 닫는다. "취소"는 [onChanged]를 부르지 않는다.
Future<void> showMaterialEditDialog({
  required BuildContext context,
  required PresetsNotifier presets,
  required String? currentColorPresetId,
  required ValueChanged<String?> onChanged,
}) {
  return showDialog<void>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: const Text('자재 변경'),
      content: SizedBox(
        width: 320,
        child: MaterialNameInput(
          colorPresetId: currentColorPresetId,
          presets: presets,
          width: 320,
          onChanged: (newId) {
            Navigator.of(dctx).pop();
            onChanged(newId);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dctx).pop(),
          child: const Text('취소'),
        ),
      ],
    ),
  );
}

int _autoArgbForName(String name) {
  final n = name.toLowerCase();
  if (n.contains('화이트') || n.contains('white') || n.contains('백색')) {
    return 0xFFF7F7F2;
  }
  if (n.contains('블랙') || n.contains('black') || n.contains('검정')) {
    return 0xFF262626;
  }
  if (n.contains('그레이') || n.contains('gray') || n.contains('회색')) {
    return 0xFFA8A29E;
  }
  final h = name.hashCode.toUnsigned(24);
  return 0xFF000000 | h;
}
