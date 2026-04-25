import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../providers/current_project_provider.dart';
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
    final p = ref.read(currentProjectProvider);
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
    final p = ref.watch(currentProjectProvider);
    final notifier = ref.read(currentProjectProvider.notifier);

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
                  notifier.updateKerf(parsed);
                },
                onEditingComplete: () {
                  final parsed = double.tryParse(_kerfCtrl.text) ?? p.kerf;
                  notifier.updateKerf(parsed);
                },
              ),
            ),
          ],
        ),
        _ToggleRow(
          label: t.lockGrain,
          value: p.grainLocked,
          onChanged: notifier.updateGrainLocked,
        ),
        _ToggleRow(
          label: t.showPartLabels,
          value: p.showPartLabels,
          onChanged: notifier.updateShowPartLabels,
        ),
        _ToggleRow(
          label: t.useSingleSheet,
          value: p.useSingleSheet,
          onChanged: notifier.updateUseSingleSheet,
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
