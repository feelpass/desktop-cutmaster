import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/stock_sheet.dart';
import '../../l10n/app_localizations.dart';
import '../providers/tabs_provider.dart';
import '../utils/part_color.dart';
import 'color_swatch_button.dart';
import 'editable_dimension_table.dart';
import 'preset_dialog.dart';
import 'preset_management_dialog.dart' show PresetKind;

class StocksTable extends ConsumerWidget {
  const StocksTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(activeProjectProvider);
    final tabs = ref.watch(tabsProvider);
    final activeId = tabs.activeId;
    if (project == null || activeId == null) return const SizedBox.shrink();
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
                    colorPresetId: s.colorPresetId,
                    grainDirection: s.grainDirection,
                  ))
              .toList(),
          leadingBuilder: (ctx, i) {
            final s = project.stocks[i];
            return ColorSwatchButton(
              entityId: s.id,
              colorPresetId: s.colorPresetId,
              palette: ColorPalette.stock,
              onChanged: (newPresetId) {
                final updated = [...project.stocks];
                updated[i] = newPresetId == null
                    ? s.copyWith(clearColor: true)
                    : s.copyWith(colorPresetId: newPresetId);
                ref.read(tabsProvider).updateStocks(activeId, updated);
              },
            );
          },
          onChanged: (rows) {
            final next = rows
                .map((r) => StockSheet(
                      id: r.id,
                      length: r.length,
                      width: r.width,
                      qty: r.qty,
                      label: r.label,
                      colorPresetId: r.colorPresetId,
                      grainDirection: r.grainDirection,
                    ))
                .toList();
            ref.read(tabsProvider).updateStocks(activeId, next);
          },
          onReorder: (rows) {
            final next = rows
                .map((r) => StockSheet(
                      id: r.id,
                      length: r.length,
                      width: r.width,
                      qty: r.qty,
                      label: r.label,
                      colorPresetId: r.colorPresetId,
                      grainDirection: r.grainDirection,
                    ))
                .toList();
            ref.read(tabsProvider).updateStocks(activeId, next);
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
              final picked = await showPresetDialog(context, PresetKind.stock);
              if (picked is StockSheet) {
                final updated = [...project.stocks, picked];
                ref.read(tabsProvider).updateStocks(activeId, updated);
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
