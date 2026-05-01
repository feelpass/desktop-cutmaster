import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// 초기 빈 상태. cutlistoptimizer.com의 빈 흰 화면보다 명확한 시작점.
class EmptyResult extends StatelessWidget {
  const EmptyResult({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.crop_square_outlined,
              size: 80, color: c.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(t.emptyResultTitle,
              style: AppTextStyles.emptyHint.copyWith(color: c.textMuted)),
          const SizedBox(height: 4),
          Text(
            t.emptyResultAction,
            style: AppTextStyles.emptyHint.copyWith(
              fontWeight: FontWeight.w500,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
