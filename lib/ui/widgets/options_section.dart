import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/tabs_provider.dart';
import '../theme/app_text_styles.dart';

class OptionsSection extends ConsumerStatefulWidget {
  const OptionsSection({super.key});

  @override
  ConsumerState<OptionsSection> createState() => _OptionsSectionState();
}

class _OptionsSectionState extends ConsumerState<OptionsSection> {
  late final TextEditingController _kerfCtrl;

  @override
  void initState() {
    super.initState();
    final p = ref.read(tabsProvider).active!.project;
    _kerfCtrl = TextEditingController(text: p.kerf.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _kerfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = ref.watch(activeProjectProvider);
    final notifier = ref.read(tabsProvider);
    final activeId = notifier.activeId;
    if (p == null || activeId == null) return const SizedBox.shrink();

    return Column(
      children: [
        // kerf 입력
        Row(
          children: [
            Expanded(child: Text(t.kerf, style: AppTextStyles.body)),
            SizedBox(
              width: 60,
              child: TextField(
                controller: _kerfCtrl,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: false,
                ),
                style: AppTextStyles.tableCell,
                onSubmitted: (v) {
                  final parsed = double.tryParse(v) ?? p.kerf;
                  notifier.updateKerf(activeId, parsed);
                },
                onEditingComplete: () {
                  final parsed = double.tryParse(_kerfCtrl.text) ?? p.kerf;
                  notifier.updateKerf(activeId, parsed);
                },
              ),
            ),
          ],
        ),
        _ToggleRow(
          label: t.lockGrain,
          value: p.grainLocked,
          onChanged: (v) => notifier.updateGrainLocked(activeId, v),
        ),
        _ToggleRow(
          label: t.showPartLabels,
          value: p.showPartLabels,
          onChanged: (v) => notifier.updateShowPartLabels(activeId, v),
        ),
        _ToggleRow(
          label: t.useSingleSheet,
          value: p.useSingleSheet,
          onChanged: (v) => notifier.updateUseSingleSheet(activeId, v),
        ),
        _ToggleRow(
          label: '단축키 안내',
          value: p.showShortcutHints,
          onChanged: (v) => notifier.updateShowShortcutHints(activeId, v),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
