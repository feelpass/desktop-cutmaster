import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cut_part.dart';
import '../../l10n/app_localizations.dart';
import '../providers/tabs_provider.dart';
import '../utils/part_color.dart';
import 'color_swatch_button.dart';
import 'editable_dimension_table.dart';
import 'preset_dialog.dart';
import 'preset_management_dialog.dart' show PresetKind;

class PartsTable extends ConsumerWidget {
  const PartsTable({super.key});

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
          rows: project.parts
              .map((p) => EditableRow(
                    id: p.id,
                    length: p.length,
                    width: p.width,
                    qty: p.qty,
                    label: p.label,
                    colorPresetId: p.colorPresetId,
                    grainDirection: p.grainDirection,
                  ))
              .toList(),
          leadingBuilder: (ctx, i) {
            final p = project.parts[i];
            return ColorSwatchButton(
              entityId: p.id,
              colorPresetId: p.colorPresetId,
              palette: ColorPalette.part,
              onChanged: (newPresetId) {
                final updated = [...project.parts];
                updated[i] = newPresetId == null
                    ? p.copyWith(clearColor: true)
                    : p.copyWith(colorPresetId: newPresetId);
                ref.read(tabsProvider).updateParts(activeId, updated);
              },
            );
          },
          onChanged: (rows) {
            final next = rows
                .map((r) => CutPart(
                      id: r.id,
                      length: r.length,
                      width: r.width,
                      qty: r.qty,
                      label: r.label,
                      colorPresetId: r.colorPresetId,
                      grainDirection: r.grainDirection,
                    ))
                .toList();
            ref.read(tabsProvider).updateParts(activeId, next);
          },
          newId: () => 'p${DateTime.now().microsecondsSinceEpoch}',
          addRowTooltip: t.addRow,
          deleteRowTooltip: t.deleteRow,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showPresetDialog(context, PresetKind.part);
              if (picked is CutPart) {
                final updated = [...project.parts, picked];
                ref.read(tabsProvider).updateParts(activeId, updated);
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
