import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 탭바 우측 + 버튼. Task 13에서 popup 메뉴 (새 / 열기 / 최근)로 확장.
class PlusButton extends StatelessWidget {
  const PlusButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('plus-button'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.add, size: 18, color: AppColors.textOnHeader),
        ),
      ),
    );
  }
}
