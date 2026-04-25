import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cut_part.dart';
import '../../domain/models/stock_sheet.dart' show GrainDirection;
import '../../l10n/app_localizations.dart';
import '../providers/preset_provider.dart';
import '../providers/tabs_provider.dart';
import '../utils/part_color.dart';
import 'color_swatch_button.dart';
import 'editable_dimension_table.dart';

class PartsTable extends ConsumerWidget {
  const PartsTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(activeProjectProvider)!;
    final tabs = ref.watch(tabsProvider);
    final activeId = tabs.activeId!;
    final t = AppLocalizations.of(context);

    return EditableDimensionTable(
      rows: project.parts
          .map((p) => EditableRow(
                id: p.id,
                length: p.length,
                width: p.width,
                qty: p.qty,
                label: p.label,
              ))
          .toList(),
      leadingBuilder: (ctx, i) {
        final p = project.parts[i];
        return ColorSwatchButton(
          entityId: p.id,
          colorPresetId: p.colorPresetId,
          palette: ColorPalette.part,
          onChanged: (newArgb) {
            final updated = [...project.parts];
            if (newArgb == null) {
              updated[i] = p.copyWith(clearColor: true);
            } else {
              final presets = ref.read(presetsProvider);
              final matched = presets.state.colors
                  .where((c) => c.argb == newArgb)
                  .toList();
              updated[i] = matched.isNotEmpty
                  ? p.copyWith(colorPresetId: matched.first.id)
                  : p.copyWith(clearColor: true);
            }
            ref.read(tabsProvider).updateParts(activeId, updated);
          },
        );
      },
      onChanged: (rows) {
        // 기존 색상 보존하면서 dimension/label만 갱신
        final next = <CutPart>[];
        for (final r in rows) {
          final existing = project.parts.where((p) => p.id == r.id).toList();
          next.add(CutPart(
            id: r.id,
            length: r.length,
            width: r.width,
            qty: r.qty,
            label: r.label,
            colorPresetId:
                existing.isNotEmpty ? existing.first.colorPresetId : null,
            grainDirection: existing.isNotEmpty
                ? existing.first.grainDirection
                : GrainDirection.none,
          ));
        }
        ref.read(tabsProvider).updateParts(activeId, next);
      },
      newId: () => 'p${DateTime.now().microsecondsSinceEpoch}',
      addRowTooltip: t.addRow,
      deleteRowTooltip: t.deleteRow,
    );
  }
}
