import 'cutting_plan.dart';

/// 결과 다이얼로그에 표시되는 종합 통계의 derived view-model.
/// CuttingPlan 자체를 변경하지 않고 (label, length, width, colorPresetId,
/// thickness) 단위로 부품을, (colorPresetId, thickness) 단위로 자재를 합산한다.
class PlanSummary {
  final int totalSheets;
  final int totalPlacedParts;
  final double totalUsedAreaMm2;
  final int totalCuts;

  /// FFD 모드처럼 cutSequence가 없어 가이로틴 라인 추정으로 도출했을 때 true.
  /// UI는 이 값에 따라 "≈" 마커를 붙인다.
  final bool cutsAreEstimated;

  final double efficiencyPercent;
  final List<MaterialUsage> materialUsages;
  final List<PartGroup> partGroups;

  const PlanSummary({
    required this.totalSheets,
    required this.totalPlacedParts,
    required this.totalUsedAreaMm2,
    required this.totalCuts,
    required this.cutsAreEstimated,
    required this.efficiencyPercent,
    required this.materialUsages,
    required this.partGroups,
  });

  /// [colorName]은 colorPresetId → 사용자가 보는 이름. null/미발견 시 '기본'.
  factory PlanSummary.fromPlan(
    CuttingPlan plan, {
    required String? Function(String? colorPresetId) colorName,
  }) {
    var placed = 0;
    var usedArea = 0.0;
    var cuts = 0;
    var anyEstimated = false;

    final materialMap = <_MaterialKey, _MaterialAcc>{};
    final partMap = <_PartKey, _PartAcc>{};

    for (final s in plan.sheets) {
      placed += s.placed.length;

      // 시트별 절단 횟수
      final sheetCuts = estimateGuillotineCuts(s);
      cuts += sheetCuts;
      if (s.cutSequence == null && s.placed.isNotEmpty) {
        anyEstimated = true;
      }

      // 시트가 어느 자재인지: 시트의 placed 첫 부품의 (color, thickness)로 결정.
      // (solver_provider가 자재별로 시트를 분리해 만들기 때문에 한 시트는 단일 자재.)
      _MaterialKey? sheetKey;
      if (s.placed.isNotEmpty) {
        final p = s.placed.first.part;
        sheetKey = _MaterialKey(p.colorPresetId, p.thickness);
      }

      double sheetUsedArea = 0;
      for (final placedPart in s.placed) {
        final part = placedPart.part;
        final area = part.length * part.width;
        usedArea += area;
        sheetUsedArea += area;

        final pk = _PartKey(
          part.label,
          part.length,
          part.width,
          part.colorPresetId,
          part.thickness,
        );
        partMap.update(
          pk,
          (acc) => acc..qty += 1,
          ifAbsent: () => _PartAcc(
            label: part.label,
            length: part.length,
            width: part.width,
            materialName: _materialDisplayName(
              colorName(part.colorPresetId),
              part.thickness,
            ),
            qty: 1,
          ),
        );
      }

      if (sheetKey != null) {
        materialMap.update(
          sheetKey,
          (acc) => acc
            ..sheetCount += 1
            ..usedAreaMm2 += sheetUsedArea,
          ifAbsent: () => _MaterialAcc(
            name: _materialDisplayName(
              colorName(sheetKey!.colorPresetId),
              sheetKey.thickness,
            ),
            sheetCount: 1,
            usedAreaMm2: sheetUsedArea,
          ),
        );
      }
    }

    final materials = materialMap.values
        .map((a) => MaterialUsage(
              name: a.name,
              sheetCount: a.sheetCount,
              usedAreaMm2: a.usedAreaMm2,
            ))
        .toList()
      ..sort((a, b) => b.sheetCount.compareTo(a.sheetCount));

    final parts = partMap.values
        .map((a) => PartGroup(
              label: a.label,
              length: a.length,
              width: a.width,
              materialName: a.materialName,
              qty: a.qty,
            ))
        .toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));

    return PlanSummary(
      totalSheets: plan.sheets.length,
      totalPlacedParts: placed,
      totalUsedAreaMm2: usedArea,
      totalCuts: cuts,
      cutsAreEstimated: anyEstimated,
      efficiencyPercent: plan.efficiencyPercent,
      materialUsages: materials,
      partGroups: parts,
    );
  }
}

class MaterialUsage {
  final String name;
  final int sheetCount;
  final double usedAreaMm2;

  const MaterialUsage({
    required this.name,
    required this.sheetCount,
    required this.usedAreaMm2,
  });
}

class PartGroup {
  final String label;
  final double length;
  final double width;
  final String materialName;
  final int qty;

  const PartGroup({
    required this.label,
    required this.length,
    required this.width,
    required this.materialName,
    required this.qty,
  });
}

String _materialDisplayName(String? colorName, double thickness) {
  final base = (colorName == null || colorName.isEmpty) ? '기본' : colorName;
  if (thickness <= 0) return base;
  return '$base ${thickness.toStringAsFixed(0)}T';
}

class _MaterialKey {
  final String? colorPresetId;
  final double thickness;
  const _MaterialKey(this.colorPresetId, this.thickness);

  @override
  bool operator ==(Object other) =>
      other is _MaterialKey &&
      other.colorPresetId == colorPresetId &&
      other.thickness == thickness;

  @override
  int get hashCode => Object.hash(colorPresetId, thickness);
}

class _MaterialAcc {
  final String name;
  int sheetCount;
  double usedAreaMm2;
  _MaterialAcc({
    required this.name,
    required this.sheetCount,
    required this.usedAreaMm2,
  });
}

class _PartKey {
  final String label;
  final double length;
  final double width;
  final String? colorPresetId;
  final double thickness;
  const _PartKey(
    this.label,
    this.length,
    this.width,
    this.colorPresetId,
    this.thickness,
  );

  @override
  bool operator ==(Object other) =>
      other is _PartKey &&
      other.label == label &&
      other.length == length &&
      other.width == width &&
      other.colorPresetId == colorPresetId &&
      other.thickness == thickness;

  @override
  int get hashCode =>
      Object.hash(label, length, width, colorPresetId, thickness);
}

class _PartAcc {
  final String label;
  final double length;
  final double width;
  final String materialName;
  int qty;
  _PartAcc({
    required this.label,
    required this.length,
    required this.width,
    required this.materialName,
    required this.qty,
  });
}
