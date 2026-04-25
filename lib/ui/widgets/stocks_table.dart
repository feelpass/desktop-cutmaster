import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/stock_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../providers/current_project_provider.dart';
import 'editable_dimension_table.dart';
import 'preset_dialog.dart';

class StocksTable extends ConsumerWidget {
  const StocksTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(currentProjectProvider);
    final t = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditableDimensionTable(
          rows: project.stocks
              .map((s) => EditableRow(
                    id: s.id,
                    length: s.length,
                    width: s.width,
                    qty: s.qty,
                    label: s.label,
                  ))
              .toList(),
          onChanged: (rows) {
            final next = rows
                .map((r) => StockSheet(
                      id: r.id,
                      length: r.length,
                      width: r.width,
                      qty: r.qty,
                      label: r.label,
                    ))
                .toList();
            ref.read(currentProjectProvider.notifier).updateStocks(next);
          },
          newId: () => 's${DateTime.now().microsecondsSinceEpoch}',
          addRowTooltip: t.addRow,
          deleteRowTooltip: t.deleteRow,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showPresetDialog(context);
              if (picked != null) {
                final updated = [...project.stocks, picked];
                ref
                    .read(currentProjectProvider.notifier)
                    .updateStocks(updated);
              }
            },
            icon: const Icon(Icons.add_box_outlined, size: 16),
            label: Text(t.preset),
          ),
        ),
      ],
    );
  }
}
