import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/solver_provider.dart';
import 'cutting_result_pane.dart';
import 'empty_result.dart';

class RightPane extends ConsumerWidget {
  const RightPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(cuttingPlanProvider);
    if (plan == null) {
      return const EmptyResult();
    }
    return CuttingResultPane(plan: plan);
  }
}
