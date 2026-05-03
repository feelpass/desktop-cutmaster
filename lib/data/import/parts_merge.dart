import '../../domain/models/cut_part.dart';

enum MergeAction { overwrite, addQty, renameAndAdd, cancel }

class PartsMergeConflict {
  final int existingIndex;
  final CutPart existing;
  final CutPart incoming;

  const PartsMergeConflict({
    required this.existingIndex,
    required this.existing,
    required this.incoming,
  });
}

class PartsMergeResult {
  final List<CutPart> mergedParts;
  final int addedCount;
  final int overwrittenCount;
  final int qtyMergedCount;
  final int renamedCount;

  const PartsMergeResult({
    required this.mergedParts,
    this.addedCount = 0,
    this.overwrittenCount = 0,
    this.qtyMergedCount = 0,
    this.renamedCount = 0,
  });
}

/// 충돌 키: (label.trim(), colorPresetId, length, width, thickness)
/// grainDirection은 키에서 제외.
({
  String label,
  String? color,
  double length,
  double width,
  double thickness,
}) _key(CutPart p) => (
      label: p.label.trim(),
      color: p.colorPresetId,
      length: p.length,
      width: p.width,
      thickness: p.thickness,
    );

List<PartsMergeConflict> detectConflicts(
  List<CutPart> existing,
  List<CutPart> incoming,
) {
  final conflicts = <PartsMergeConflict>[];
  for (final inc in incoming) {
    final incKey = _key(inc);
    for (var i = 0; i < existing.length; i++) {
      if (_key(existing[i]) == incKey) {
        conflicts.add(PartsMergeConflict(
          existingIndex: i,
          existing: existing[i],
          incoming: inc,
        ));
        break;
      }
    }
  }
  return conflicts;
}

PartsMergeResult applyMerge(
  List<CutPart> existing,
  List<CutPart> incoming,
  MergeAction action,
) {
  if (action == MergeAction.cancel) {
    return PartsMergeResult(mergedParts: List<CutPart>.from(existing));
  }

  final merged = List<CutPart>.from(existing);
  final conflictByIncoming = <int, int>{};
  for (var j = 0; j < incoming.length; j++) {
    final incKey = _key(incoming[j]);
    for (var i = 0; i < existing.length; i++) {
      if (_key(existing[i]) == incKey) {
        conflictByIncoming[j] = i;
        break;
      }
    }
  }

  var added = 0;
  var overwritten = 0;
  var qtyMerged = 0;
  var renamed = 0;

  for (var j = 0; j < incoming.length; j++) {
    final inc = incoming[j];
    final existingIdx = conflictByIncoming[j];

    if (existingIdx == null) {
      merged.add(inc);
      added++;
      continue;
    }

    switch (action) {
      case MergeAction.overwrite:
        merged[existingIdx] = inc;
        overwritten++;
        break;
      case MergeAction.addQty:
        merged[existingIdx] = merged[existingIdx]
            .copyWith(qty: merged[existingIdx].qty + inc.qty);
        qtyMerged++;
        break;
      case MergeAction.renameAndAdd:
        final base = _stripIndexSuffix(inc.label.trim());
        var n = 2;
        var candidate = '$base ($n)';
        while (_keyInUse(merged, inc, candidate)) {
          n++;
          candidate = '$base ($n)';
        }
        merged.add(inc.copyWith(label: candidate));
        renamed++;
        break;
      case MergeAction.cancel:
        break;
    }
  }

  return PartsMergeResult(
    mergedParts: merged,
    addedCount: added,
    overwrittenCount: overwritten,
    qtyMergedCount: qtyMerged,
    renamedCount: renamed,
  );
}

final RegExp _indexSuffixPattern = RegExp(r'^(.*?)\s*\((\d+)\)$');

String _stripIndexSuffix(String label) {
  final m = _indexSuffixPattern.firstMatch(label);
  if (m == null) return label;
  return m.group(1)!.trim();
}

bool _keyInUse(List<CutPart> parts, CutPart inc, String candidateLabel) {
  for (final p in parts) {
    if (p.label.trim() == candidateLabel &&
        p.colorPresetId == inc.colorPresetId &&
        p.length == inc.length &&
        p.width == inc.width &&
        p.thickness == inc.thickness) {
      return true;
    }
  }
  return false;
}
