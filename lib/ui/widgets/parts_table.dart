import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/csv/parts_csv_exporter.dart';
import '../../data/csv/parts_csv_importer.dart';
import '../../data/excel/parts_excel_importer.dart';
import '../../data/import/parts_merge.dart';
import '../../data/preset/preset_models.dart';
import '../../domain/models/cut_part.dart';
import '../../domain/models/stock_sheet.dart' show GrainDirection;
import '../../l10n/app_localizations.dart';
import '../providers/db_provider.dart';
import '../providers/preset_provider.dart';
import '../providers/tabs_provider.dart';
import '../theme/app_colors.dart';
import '../utils/part_color.dart';
import 'editable_dimension_table.dart';
import 'material_name_input.dart';
import 'parts_merge_dialog.dart';
import 'preset_dialog.dart';
import 'preset_management_dialog.dart' show PresetKind;

/// 부품 가져오기 다이얼로그가 마지막으로 사용한 폴더를 기억하기 위한 setting key.
/// CSV 전용이던 시절의 키 이름을 그대로 유지 — 기존 사용자 설정 보존.
const _kCsvImportDirKey = 'last_csv_import_dir';

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
              onPressed: () => _onExportCsv(context, ref),
              icon: const Icon(Icons.file_download_outlined, size: 14),
              label: const Text('CSV 내보내기'),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28)),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              onPressed: () => _onImportFile(context, ref),
              icon: const Icon(Icons.file_upload_outlined, size: 14),
              label: const Text('부품 가져오기'),
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
            final preset = ref.read(presetsProvider).colorById(p.colorPresetId);
            final color = resolveColor(p.id, preset?.argb, ColorPalette.part);
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showMaterialEditDialog(
                context: ctx,
                presets: ref.read(presetsProvider),
                currentColorPresetId: p.colorPresetId,
                onChanged: (newPresetId) {
                  final updated = [...project.parts];
                  updated[i] = newPresetId == null
                      ? p.copyWith(clearColor: true)
                      : p.copyWith(colorPresetId: newPresetId);
                  ref.read(tabsProvider).updateParts(activeId, updated);
                },
              ),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE6E6E6),
                    width: 1,
                  ),
                ),
              ),
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
        _QuickAddPartRow(
          newId: () => 'p${DateTime.now().microsecondsSinceEpoch}',
          presets: ref.read(presetsProvider),
          onAdd: (part) {
            final updated = [...project.parts, part];
            ref.read(tabsProvider).updateParts(activeId, updated);
          },
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

  Future<void> _onImportFile(BuildContext context, WidgetRef ref) async {
    // 시작 폴더: 마지막 사용 폴더 → 사용자 Documents → 시스템 기본.
    // macOS는 initialDirectory 미지정 시 picker가 sandbox 기본 위치에서 열려
    // 사용자가 원하는 폴더로 진입하기 어려움.
    String? initialDir;
    try {
      final db = await ref.read(workspaceDbProvider.future);
      initialDir = await db.getSetting(_kCsvImportDirKey);
      if (initialDir != null && !await Directory(initialDir).exists()) {
        initialDir = null;
      }
      initialDir ??= (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      initialDir = null;
    }
    if (!context.mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xlsm'],
      initialDirectory: initialDir,
    );
    if (result == null || result.files.single.path == null) return;
    if (!context.mounted) return;

    // 다음 가져오기를 위해 선택한 파일의 폴더를 기억.
    final pickedPath = result.files.single.path!;
    try {
      final db = await ref.read(workspaceDbProvider.future);
      await db.setSetting(_kCsvImportDirKey, p.dirname(pickedPath));
    } catch (_) {
      // 영속화 실패는 무시 — 다음 번에 기본값으로 폴백.
    }

    try {
      final file = File(pickedPath);
      final ext = p.extension(pickedPath).toLowerCase();
      final List<ParsedPartRow> rows;
      switch (ext) {
        case '.csv':
          rows = PartsCsvImporter.parse(await file.readAsString());
          break;
        case '.xlsx':
        case '.xlsm':
          rows = PartsExcelImporter.parse(await file.readAsBytes());
          break;
        default:
          throw FormatException('지원하지 않는 파일 형식: $ext');
      }
      if (rows.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일에서 부품을 찾지 못했습니다')),
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

      // 충돌 감지 후 사용자 액션에 따라 머지.
      final conflicts = detectConflicts(project.parts, parts);
      MergeAction action;
      if (conflicts.isEmpty) {
        // 충돌 0건이면 단순 append (기존 동작 유지).
        action = MergeAction.overwrite; // overwrite는 비충돌 행만 append하므로 동등.
      } else {
        if (!context.mounted) return;
        final picked = await showPartsMergeDialog(context, conflicts);
        action = picked ?? MergeAction.cancel;
      }
      if (action == MergeAction.cancel) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('가져오기를 취소했습니다')),
          );
        }
        return;
      }
      final result = applyMerge(project.parts, parts, action);
      tabs.updateParts(activeId, result.mergedParts);

      // ARTICLE → 프로젝트명 (비어있을 때만)
      final article = rows.first.article;
      if (article.isNotEmpty &&
          (project.name.isEmpty || project.name == '새 프로젝트')) {
        tabs.updateName(activeId, article);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_summary(result))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가져오기 실패: $e')),
        );
      }
    }
  }

  Future<void> _onExportCsv(BuildContext context, WidgetRef ref) async {
    final tabs = ref.read(tabsProvider);
    final project = tabs.active?.project;
    if (project == null) return;
    if (project.parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내보낼 부품이 없습니다')),
      );
      return;
    }

    // 시작 폴더: 마지막 가져오기 폴더 → Documents.
    String? initialDir;
    try {
      final db = await ref.read(workspaceDbProvider.future);
      initialDir = await db.getSetting(_kCsvImportDirKey);
      if (initialDir != null && !await Directory(initialDir).exists()) {
        initialDir = null;
      }
      initialDir ??= (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      initialDir = null;
    }
    if (!context.mounted) return;

    final defaultName =
        '${project.name.isNotEmpty ? project.name : 'parts'}.CSV';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'CSV로 내보내기',
      fileName: defaultName,
      initialDirectory: initialDir,
      type: FileType.custom,
      allowedExtensions: ['csv', 'CSV'],
    );
    if (savePath == null) return;

    try {
      final colors = ref.read(presetsProvider).state.colors;
      final csv = PartsCsvExporter.export(
        parts: project.parts,
        articleName: project.name,
        colors: colors,
      );
      await File(savePath).writeAsString(csv);

      // 다음 사용을 위해 폴더 기억.
      try {
        final db = await ref.read(workspaceDbProvider.future);
        await db.setSetting(_kCsvImportDirKey, p.dirname(savePath));
      } catch (_) {/* 영속화 실패는 무시 */}

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${project.parts.length}개 부품을 내보냈습니다')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
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

  /// import 결과 통계를 한 줄 메시지로 요약.
  String _summary(PartsMergeResult r) {
    final parts = <String>[];
    if (r.addedCount > 0) parts.add('추가 ${r.addedCount}');
    if (r.qtyMergedCount > 0) parts.add('수량 합산 ${r.qtyMergedCount}');
    if (r.overwrittenCount > 0) parts.add('덮어쓰기 ${r.overwrittenCount}');
    if (r.renamedCount > 0) parts.add('이름 변경 추가 ${r.renamedCount}');
    if (parts.isEmpty) return '변경 사항이 없습니다';
    return parts.join(', ');
  }
}

/// "프리셋에서 추가" 버튼 위에 놓이는 인라인 부품 입력 폼.
/// 부품명/가로/세로/두께/결/자재/수량/메모를 즉시 입력해 행을 추가한다.
/// 가로·세로 둘 다 양수일 때만 + 버튼 활성화. Enter 키로 제출 가능.
/// 폭이 좁으면 Wrap으로 자동 줄바꿈된다.
class _QuickAddPartRow extends StatefulWidget {
  const _QuickAddPartRow({
    required this.newId,
    required this.presets,
    required this.onAdd,
  });

  final String Function() newId;
  final void Function(CutPart part) onAdd;
  final PresetsNotifier presets;

  @override
  State<_QuickAddPartRow> createState() => _QuickAddPartRowState();
}

class _QuickAddPartRowState extends State<_QuickAddPartRow> {
  final _labelCtrl = TextEditingController();
  final _lenCtrl = TextEditingController();
  final _widCtrl = TextEditingController();
  final _thickCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _memoCtrl = TextEditingController();
  String? _colorPresetId;
  GrainDirection _grain = GrainDirection.none;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _lenCtrl.dispose();
    _widCtrl.dispose();
    _thickCtrl.dispose();
    _qtyCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  bool get _canAdd {
    final l = double.tryParse(_lenCtrl.text) ?? 0;
    final w = double.tryParse(_widCtrl.text) ?? 0;
    return l > 0 && w > 0;
  }

  void _submit() {
    if (!_canAdd) return;
    final part = CutPart(
      id: widget.newId(),
      label: _labelCtrl.text.trim(),
      length: double.tryParse(_lenCtrl.text) ?? 0,
      width: double.tryParse(_widCtrl.text) ?? 0,
      qty: int.tryParse(_qtyCtrl.text) ?? 1,
      thickness: double.tryParse(_thickCtrl.text) ?? 18,
      colorPresetId: _colorPresetId,
      grainDirection: _grain,
      memo: _memoCtrl.text,
    );
    widget.onAdd(part);
    _labelCtrl.clear();
    _lenCtrl.clear();
    _widCtrl.clear();
    _thickCtrl.clear();
    _qtyCtrl.text = '1';
    _memoCtrl.clear();
    setState(() {
      _colorPresetId = null;
      _grain = GrainDirection.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.colors;
    // 부품 리스트 헤더/행과 동일한 칼럼 폭으로 정렬 (spaceBetween).
    // drag handle(24) + #(28) + leading(30) 자리는 입력 폼에서 비워두지만
    // 폭은 동일하게 유지해야 표 헤더와 시각적으로 정렬됨.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: pal.surfaceAlt,
          border: Border.all(color: pal.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 24), // drag handle 자리
            SizedBox(
              width: 28,
              child: Icon(Icons.add_circle_outline,
                  size: 14, color: pal.textSecondary),
            ),
            const SizedBox(width: 30), // leading swatch 자리
            SizedBox(width: 220, child: _input(_labelCtrl, '부품명', false)),
            SizedBox(width: 60, child: _input(_lenCtrl, '가로', true)),
            SizedBox(width: 60, child: _input(_widCtrl, '세로', true)),
            SizedBox(width: 60, child: _input(_thickCtrl, '두께', true)),
            SizedBox(
              width: 64,
              child: GrainToggle(
                value: _grain,
                onChanged: (next) => setState(() => _grain = next),
              ),
            ),
            SizedBox(
              width: 140,
              child: MaterialNameInput(
                colorPresetId: _colorPresetId,
                presets: widget.presets,
                width: 140,
                hintText: '자재',
                onChanged: (newPresetId) =>
                    setState(() => _colorPresetId = newPresetId),
              ),
            ),
            SizedBox(width: 80, child: _input(_qtyCtrl, '수량', true)),
            SizedBox(width: 260, child: _input(_memoCtrl, '메모', false)),
            SizedBox(
              width: 28,
              height: 28,
              child: Material(
                color: _canAdd ? AppColors.accent : const Color(0xFFE6E6E6),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: _canAdd ? _submit : null,
                  child: Center(
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color:
                          _canAdd ? Colors.white : const Color(0xFF8A8F98),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, bool numeric) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: ctrl,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textAlign: numeric ? TextAlign.center : TextAlign.left,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8A8F98)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
