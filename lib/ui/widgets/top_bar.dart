import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/current_project_provider.dart';
import '../providers/solver_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'project_dropdown.dart';

class TopBar extends ConsumerWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final isCalculating = ref.watch(isCalculatingProvider);
    final project = ref.watch(currentProjectProvider);

    return Container(
      height: 48,
      color: AppColors.header,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // 로고 + 앱 이름
          const Icon(Icons.crop, color: AppColors.textOnHeader, size: 20),
          const SizedBox(width: 8),
          Text(t.appTitle, style: AppTextStyles.topBarTitle),

          const SizedBox(width: 24),

          // 프로젝트 dropdown
          Expanded(child: ProjectDropdown(currentName: project.name)),

          // 우측 액션들
          ElevatedButton.icon(
            onPressed: isCalculating
                ? null
                : () {
                    // 활성 TextField commit 강제 (onEditingComplete 트리거)
                    FocusManager.instance.primaryFocus?.unfocus();
                    // 1 frame 기다려서 commit 반영 후 계산
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      runCalculate(ref);
                    });
                  },
            icon: isCalculating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow, size: 18),
            label: Text(t.calculate),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              // 자동 저장이라 명시 저장은 즉시 trigger만
            },
            icon: const Icon(Icons.save, color: AppColors.textOnHeader, size: 20),
            tooltip: t.save,
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings,
                color: AppColors.textOnHeader, size: 20),
            tooltip: t.settings,
          ),
        ],
      ),
    );
  }
}
