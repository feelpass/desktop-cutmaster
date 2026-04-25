import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_colors.dart';
import 'widgets/left_pane.dart';
import 'widgets/right_pane.dart';
import 'widgets/top_bar.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Column(
        children: [
          TopBar(),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 380, child: LeftPane()),
                VerticalDivider(width: 1, color: AppColors.border),
                Expanded(child: RightPane()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
