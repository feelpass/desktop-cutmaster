import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/solver_provider.dart';
import 'cutting_result_pane.dart';
import 'empty_result.dart';

class RightPane extends ConsumerWidget {
  const RightPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // displayedPlanProvider: auto-recommend chip 토글에 따라 winner/runner-up 중 하나.
    // 일반(non-auto) 모드에선 cuttingPlanProvider와 동일.
    final plan = ref.watch(displayedPlanProvider);
    if (plan == null) {
      return const EmptyResult();
    }
    return CuttingResultPane(plan: plan);
  }
}
