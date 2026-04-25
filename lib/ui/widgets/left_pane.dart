import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'options_section.dart';
import 'parts_table.dart';
import 'stocks_table.dart';

class LeftPane extends ConsumerWidget {
  const LeftPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Container(
      color: AppColors.surface,
      child: ListView(
        children: [
          _Section(
            title: t.parts,
            icon: Icons.inventory_2_outlined,
            child: const PartsTable(),
          ),
          _Section(
            title: t.stockSheets,
            icon: Icons.layers_outlined,
            child: const StocksTable(),
          ),
          _Section(
            title: t.options,
            icon: Icons.tune,
            child: const OptionsSection(),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.sectionHeaderBg,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(_expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                      size: 18, color: AppColors.tableHeaderText),
                  const SizedBox(width: 4),
                  Icon(widget.icon, size: 14, color: AppColors.tableHeaderText),
                  const SizedBox(width: 6),
                  Text(widget.title, style: AppTextStyles.sectionHeader),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: widget.child,
          ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}
