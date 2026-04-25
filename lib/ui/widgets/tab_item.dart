import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class TabItem extends StatelessWidget {
  const TabItem({
    super.key,
    required this.displayName,
    required this.isActive,
    required this.isDirty,
    required this.isUntitled,
    required this.onTap,
    required this.onClose,
    required this.onRenameSubmit,
  });

  final String displayName;
  final bool isActive;
  final bool isDirty;
  final bool isUntitled;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ValueChanged<String> onRenameSubmit;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? Colors.white : Colors.white24;
    final fg = isActive ? Colors.black87 : AppColors.textOnHeader;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        child: Row(
          children: [
            if (isUntitled || isDirty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  key: const ValueKey('tab-dirty-dot'),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: fg.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontSize: 13),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              key: const ValueKey('tab-close'),
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
