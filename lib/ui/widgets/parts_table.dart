import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/csv/parts_csv_importer.dart';
import '../../data/preset/preset_models.dart';
import '../../domain/models/cut_part.dart';
import '../../l10n/app_localizations.dart';
import '../providers/preset_provider.dart';
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
        Row(
          children: [
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _onImportCsv(context, ref),
              icon: const Icon(Icons.file_upload_outlined, size: 14),
              label: const Text('CSV 가져오기'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28)),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
                    thickness: p.thickness,
                    fileName: p.fileName,
                    edges: p.edges,
                    memo: p.memo,
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
            final byId = {for (final p in project.parts) p.id: p};
            final next = rows.map((r) {
              final orig = byId[r.id];
              return CutPart(
                id: r.id,
                length: r.length,
                width: r.width,
                qty: r.qty,
                label: r.label,
                colorPresetId: r.colorPresetId,
                grainDirection: r.grainDirection,
                thickness: r.thickness ?? orig?.thickness ?? 18,
                priority: orig?.priority ?? 1,
                edges: orig?.edges ?? const ['', '', '', ''],
                fileName: orig?.fileName ?? '',
                groove: orig?.groove ?? '',
                memo: r.memo,
              );
            }).toList();
            ref.read(tabsProvider).updateParts(activeId, next);
          },
          onReorder: (rows) {
            final byId = {for (final p in project.parts) p.id: p};
            final next = rows.map((r) {
              final orig = byId[r.id];
              return CutPart(
                id: r.id,
                length: r.length,
                width: r.width,
                qty: r.qty,
                label: r.label,
                colorPresetId: r.colorPresetId,
                grainDirection: r.grainDirection,
                thickness: r.thickness ?? orig?.thickness ?? 18,
                priority: orig?.priority ?? 1,
                edges: orig?.edges ?? const ['', '', '', ''],
                fileName: orig?.fileName ?? '',
                groove: orig?.groove ?? '',
                memo: r.memo,
              );
            }).toList();
            ref.read(tabsProvider).updateParts(activeId, next);
          },
          newId: () => 'p${DateTime.now().microsecondsSinceEpoch}',
          addRowTooltip: t.addRow,
          deleteRowTooltip: t.deleteRow,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showPresetDialog(context, PresetKind.part);
              if (picked is CutPart) {
                final updated = [...project.parts, picked];
                ref.read(tabsProvider).updateParts(activeId, updated);
              }
            },
            icon: const Icon(Icons.add_box_outlined, size: 16),
            label: const Text('프리셋에서 추가'),
          ),
        ),
      ],
    );
  }

  Future<void> _onImportCsv(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'CSV'],
    );
    if (result == null || result.files.single.path == null) return;
    if (!context.mounted) return;

    try {
      final file = File(result.files.single.path!);
      final text = await file.readAsString();
      final rows = PartsCsvImporter.parse(text);
      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV에서 부품을 찾지 못했습니다')),
          );
        }
        return;
      }

      final tabs = ref.read(tabsProvider);
      final activeId = tabs.activeId;
      final project = tabs.active?.project;
      if (activeId == null || project == null) return;

      final presets = ref.read(presetsProvider);
      final parts = <CutPart>[];
      for (final r in rows) {
        final colorId = await _findOrCreateColorByName(
            r.materialColorName, presets);
        parts.add(CutPart(
          id: 'p${DateTime.now().microsecondsSinceEpoch}_${parts.length}',
          length: r.length,
          width: r.width,
          qty: r.qty,
          label: r.label,
          colorPresetId: colorId,
          grainDirection: r.grain,
          thickness: r.materialThickness,
          edges: r.edges,
          fileName: r.fileName,
          groove: r.groove,
        ));
      }

      tabs.updateParts(activeId, parts);

      // ARTICLE → 프로젝트명 (비어있을 때만)
      final article = rows.first.article;
      if (article.isNotEmpty &&
          (project.name.isEmpty || project.name == '새 프로젝트')) {
        tabs.updateName(activeId, article);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${parts.length}개 부품을 가져왔습니다')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV 가져오기 실패: $e')),
        );
      }
    }
  }

  /// 이름으로 ColorPreset 찾기. 없으면 자동 생성하고 그 id 반환.
  /// 빈 이름이면 null (자동 색상).
  Future<String?> _findOrCreateColorByName(
      String name, PresetsNotifier presets) async {
    if (name.isEmpty) return null;
    final existing = presets.state.colors.firstWhere(
      (c) => c.name == name,
      orElse: () => const ColorPreset(id: '', name: '', argb: 0),
    );
    if (existing.id.isNotEmpty) return existing.id;
    final created = ColorPreset(
      id: 'cp_csv_${name.hashCode.toUnsigned(16).toRadixString(16)}',
      name: name,
      argb: _autoArgbForName(name),
    );
    await presets.addColor(created);
    return created.id;
  }

  /// 새 색상에 대한 기본 ARGB — 이름 기반 hash로 안정적으로 결정.
  /// 화이트/white 같은 명백한 이름은 흰색 톤으로 매핑.
  int _autoArgbForName(String name) {
    final n = name.toLowerCase();
    if (n.contains('화이트') || n.contains('white') || n.contains('백색')) {
      return 0xFFF7F7F2;
    }
    if (n.contains('블랙') || n.contains('black') || n.contains('검정')) {
      return 0xFF262626;
    }
    if (n.contains('그레이') || n.contains('gray') || n.contains('회색')) {
      return 0xFFA8A29E;
    }
    final h = name.hashCode.toUnsigned(24);
    return 0xFF000000 | h;
  }
}
