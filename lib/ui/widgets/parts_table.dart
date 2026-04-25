import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/cut_part.dart';
import '../../l10n/app_localizations.dart';
import '../providers/current_project_provider.dart';
import 'editable_dimension_table.dart';

class PartsTable extends ConsumerWidget {
  const PartsTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(currentProjectProvider);
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
      onChanged: (rows) {
        final next = rows
            .map((r) => CutPart(
                  id: r.id,
                  length: r.length,
                  width: r.width,
                  qty: r.qty,
                  label: r.label,
                ))
            .toList();
        ref.read(currentProjectProvider.notifier).updateParts(next);
      },
      newId: () => 'p${DateTime.now().microsecondsSinceEpoch}',
      addRowTooltip: t.addRow,
      deleteRowTooltip: t.deleteRow,
    );
  }
}
