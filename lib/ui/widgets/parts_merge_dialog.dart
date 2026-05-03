import 'package:flutter/material.dart';

import '../../data/import/parts_merge.dart';
import '../../domain/models/cut_part.dart';

Future<MergeAction?> showPartsMergeDialog(
  BuildContext context,
  List<PartsMergeConflict> conflicts,
) {
  return showDialog<MergeAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PartsMergeDialog(conflicts: conflicts),
  );
}

class _PartsMergeDialog extends StatelessWidget {
  final List<PartsMergeConflict> conflicts;
  const _PartsMergeDialog({required this.conflicts});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('중복 부품이 있습니다'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '기존 목록과 동일한 부품 ${conflicts.length}개가 발견되었습니다.\n(이름 + 자재 + 사이즈 모두 일치)',
              style: const TextStyle(fontSize: 14, color: Color(0xFF62666D)),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final c in conflicts)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${c.incoming.label}  '
                          '${_formatSize(c.incoming)}  '
                          '×${c.incoming.qty}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF62666D),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '어떻게 처리할까요?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, MergeAction.cancel),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, MergeAction.renameAndAdd),
          child: const Text('이름 변경 후 추가'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, MergeAction.addQty),
          child: const Text('수량 증가'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, MergeAction.overwrite),
          child: const Text('덮어쓰기'),
        ),
      ],
    );
  }

  String _formatSize(CutPart c) {
    final l = c.length.toStringAsFixed(0);
    final w = c.width.toStringAsFixed(0);
    final t = c.thickness.toStringAsFixed(0);
    return '$l×$w (${t}T)';
  }
}
