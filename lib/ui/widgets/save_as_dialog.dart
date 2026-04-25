import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 첫 저장 시 파일 이름을 묻는 작은 다이얼로그.
/// 반환: 사용자가 입력한 이름 (trim됨), 취소 시 null.
Future<String?> showSaveAsDialog(
  BuildContext context, {
  required String initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _SaveAsDialog(initialName: initialName),
  );
}

class _SaveAsDialog extends StatefulWidget {
  const _SaveAsDialog({required this.initialName});
  final String initialName;
  @override
  State<_SaveAsDialog> createState() => _SaveAsDialogState();
}

class _SaveAsDialogState extends State<_SaveAsDialog> {
  static final _forbidden = RegExp(r'[\\/:*?"<>|]');
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialName.length,
      );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('저장'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '파일 이름',
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        inputFormatters: [FilteringTextInputFormatter.deny(_forbidden)],
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          // TODO(future): "다른 위치에 저장..." button using file_picker getDirectoryPath
          onPressed: _ctrl.text.trim().isEmpty ? null : _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
