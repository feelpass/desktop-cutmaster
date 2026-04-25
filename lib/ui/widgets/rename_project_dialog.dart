import 'package:flutter/material.dart';

/// 프로젝트 이름 변경 다이얼로그.
/// 결과: 새 이름 (확인 시) / null (취소 또는 빈 문자열)
Future<String?> showRenameProjectDialog(
  BuildContext context, {
  required String currentName,
}) {
  final controller = TextEditingController(text: currentName);
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: currentName.length,
  );

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('프로젝트 이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) {
            final trimmed = v.trim();
            Navigator.pop(ctx, trimmed.isEmpty ? null : trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              Navigator.pop(ctx, trimmed.isEmpty ? null : trimmed);
            },
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}
