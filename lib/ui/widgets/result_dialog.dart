import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/solver_provider.dart';
import '../theme/app_colors.dart';
import 'cutting_result_pane.dart';
import 'empty_result.dart';
import 'result_summary_panel.dart';

/// 계산 결과를 모달 다이얼로그로 표시.
/// [showResultDialog]가 표준 진입점이며 ESC/X 모두 닫기 가능.
Future<void> showResultDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ResultDialog(),
  );
}

class _ResultDialog extends ConsumerStatefulWidget {
  const _ResultDialog();

  @override
  ConsumerState<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends ConsumerState<_ResultDialog> {
  String? _exportingMessage; // null이면 export 중 아님

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(displayedPlanProvider);
    final size = MediaQuery.of(context).size;
    final exporting = _exportingMessage;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * 0.92,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(
              onClose: exporting != null
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
            Divider(height: 1, color: context.colors.border),
            Expanded(
              child: Stack(
                children: [
                  plan == null
                      ? const EmptyResult()
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ResultSummaryPanel(
                              plan: plan,
                              onExportStart: (msg) =>
                                  setState(() => _exportingMessage = msg),
                              onExportEnd: () =>
                                  setState(() => _exportingMessage = null),
                            ),
                            VerticalDivider(
                                width: 1, color: context.colors.border),
                            Expanded(child: CuttingResultPane(plan: plan)),
                          ],
                        ),
                  if (exporting != null) _LoadingOverlay(message: exporting),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(width: 14),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(Icons.bar_chart, size: 20, color: context.colors.textPrimary),
          const SizedBox(width: 8),
          const Text(
            '계산 결과',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            tooltip: '닫기',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}
