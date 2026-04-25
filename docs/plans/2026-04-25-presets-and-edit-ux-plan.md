# 글로벌 프리셋 + LeftPane 편집성 개선 — 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** 색상/부품/자재 3종 글로벌 프리셋을 도입하고(참조 모델), LeftPane의
행 편집 UX를 1줄+메타 줄 레이아웃 + 수량 +/- 스피너 + 색상 이름 텍스트
표시로 개선한다.

**Architecture:** `~/Library/Application Support/cutmaster/presets.json`에
색상/부품/자재 프리셋을 저장하고 `Riverpod` `ChangeNotifier` provider로
앱 전역에 공유한다. `CutPart`/`StockSheet`의 `colorArgb`(int) →
`colorPresetId`(String?)로 모델을 바꾸고, `.cutmaster fromJson`에서
legacy `color: int` 필드를 가장 가까운 색상 프리셋 id로 자동 매핑한다.
`EditableDimensionTable`은 행을 1줄(편집)+메타 줄(읽기 전용)로 재구성한다.

**Tech Stack:** Flutter 3.10.8, Dart, `flutter_riverpod ^2.5.1`,
`path_provider ^2.1.4`, `flutter_test`, `integration_test`,
`flutter_colorpicker` (신규 추가).

**디자인 문서:** `docs/plans/2026-04-25-presets-and-edit-ux-design.md`

---

## Phase A — 데이터 레이어

### Task 1: ColorPreset 모델 + 단위 테스트

**Files:**
- Create: `lib/data/preset/preset_models.dart`
- Test: `test/data/preset/preset_models_test.dart`

**Step 1: 실패하는 테스트 작성**

`test/data/preset/preset_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/data/preset/preset_models.dart';

void main() {
  group('ColorPreset', () {
    test('toJson / fromJson round-trip', () {
      const p = ColorPreset(id: 'cp_x', name: '호두', argb: 0xFF8B6240);
      final j = p.toJson();
      final back = ColorPreset.fromJson(j);
      expect(back, p);
    });

    test('equality based on id+name+argb', () {
      const a = ColorPreset(id: 'cp_x', name: '호두', argb: 0xFF8B6240);
      const b = ColorPreset(id: 'cp_x', name: '호두', argb: 0xFF8B6240);
      const c = ColorPreset(id: 'cp_x', name: '자작', argb: 0xFF8B6240);
      expect(a, b);
      expect(a == c, false);
    });
  });
}
```

**Step 2: 실패 확인**

Run: `flutter test test/data/preset/preset_models_test.dart`
Expected: FAIL — "Target of URI doesn't exist".

**Step 3: 최소 구현**

`lib/data/preset/preset_models.dart`:

```dart
class ColorPreset {
  final String id;
  final String name;
  final int argb;
  const ColorPreset({required this.id, required this.name, required this.argb});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'argb': argb};

  factory ColorPreset.fromJson(Map<String, dynamic> j) => ColorPreset(
        id: j['id'] as String,
        name: j['name'] as String,
        argb: j['argb'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is ColorPreset &&
      other.id == id &&
      other.name == name &&
      other.argb == argb;

  @override
  int get hashCode => Object.hash(id, name, argb);
}
```

**Step 4: 통과 확인**

Run: `flutter test test/data/preset/preset_models_test.dart`
Expected: PASS.

**Step 5: 커밋**

```bash
git add lib/data/preset/preset_models.dart \
        test/data/preset/preset_models_test.dart
git commit -m "feat(preset): add ColorPreset model with JSON round-trip"
```

---

### Task 2: DimensionPreset 모델 + 단위 테스트

**Files:**
- Modify: `lib/data/preset/preset_models.dart`
- Modify: `test/data/preset/preset_models_test.dart`

**Step 1: 실패하는 테스트 추가**

`test/data/preset/preset_models_test.dart`에 추가:

```dart
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

// ... existing code ...

  group('DimensionPreset', () {
    test('toJson / fromJson round-trip with all fields', () {
      const d = DimensionPreset(
        id: 'dp_walnut18',
        length: 2440,
        width: 1220,
        label: '호두 18T',
        colorPresetId: 'cp_walnut',
        grain: GrainDirection.lengthwise,
      );
      expect(DimensionPreset.fromJson(d.toJson()), d);
    });

    test('toJson / fromJson with null colorPresetId (자동)', () {
      const d = DimensionPreset(
        id: 'dp_x',
        length: 600,
        width: 300,
        label: '',
        colorPresetId: null,
        grain: GrainDirection.none,
      );
      expect(DimensionPreset.fromJson(d.toJson()), d);
    });
  });
```

**Step 2: 실패 확인** — Run, expect "DimensionPreset undefined".

**Step 3: 구현**

`lib/data/preset/preset_models.dart`에 추가:

```dart
import '../../domain/models/stock_sheet.dart' show GrainDirection;

class DimensionPreset {
  final String id;
  final double length;
  final double width;
  final String label;
  final String? colorPresetId;
  final GrainDirection grain;

  const DimensionPreset({
    required this.id,
    required this.length,
    required this.width,
    required this.label,
    required this.colorPresetId,
    required this.grain,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'length': length,
        'width': width,
        'label': label,
        if (colorPresetId != null) 'colorPresetId': colorPresetId,
        'grain': grain.name,
      };

  factory DimensionPreset.fromJson(Map<String, dynamic> j) => DimensionPreset(
        id: j['id'] as String,
        length: (j['length'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        label: (j['label'] as String?) ?? '',
        colorPresetId: j['colorPresetId'] as String?,
        grain: GrainDirection.values.byName((j['grain'] as String?) ?? 'none'),
      );

  @override
  bool operator ==(Object other) =>
      other is DimensionPreset &&
      other.id == id &&
      other.length == length &&
      other.width == width &&
      other.label == label &&
      other.colorPresetId == colorPresetId &&
      other.grain == grain;

  @override
  int get hashCode =>
      Object.hash(id, length, width, label, colorPresetId, grain);
}
```

**Step 4: 통과 확인** — Run, expect PASS.

**Step 5: 커밋**

```bash
git add lib/data/preset/preset_models.dart \
        test/data/preset/preset_models_test.dart
git commit -m "feat(preset): add DimensionPreset model with grain + colorPresetId"
```

---

### Task 3: 시드 데이터 (24색 + 자재 6종)

**Files:**
- Create: `lib/data/preset/preset_seeds.dart`
- Test: `test/data/preset/preset_seeds_test.dart`

**Step 1: 실패하는 테스트**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/data/preset/preset_seeds.dart';

void main() {
  test('seed has 24 color presets with unique ids', () {
    final ids = seedColorPresets.map((c) => c.id).toSet();
    expect(seedColorPresets.length, 24);
    expect(ids.length, 24);
  });

  test('seed has 6 stock presets', () {
    expect(seedStockPresets.length, 6);
  });

  test('seed part presets is empty', () {
    expect(seedPartPresets, isEmpty);
  });

  test('all stock seeds reference null colorPresetId (자동)', () {
    for (final s in seedStockPresets) {
      expect(s.colorPresetId, isNull, reason: '시드 자재는 색 자동');
    }
  });

  test('color seeds include both vivid (빨강) and wood-tone (호두)', () {
    final names = seedColorPresets.map((c) => c.name).toList();
    expect(names, contains('빨강'));
    expect(names, contains('호두'));
  });
}
```

**Step 2: 실패 확인**

**Step 3: 구현** — 현재 `lib/ui/utils/part_color.dart`의 `partColorPresets`
12색 + `stockColorPresets` 12색을 `cp_<slug>` id 부여하면서 시드로 이전.
자재 6종은 `lib/ui/widgets/preset_dialog.dart`의 `_presets`를 시드로 이전.

```dart
import '../../domain/models/stock_sheet.dart' show GrainDirection;
import 'preset_models.dart';

const seedColorPresets = <ColorPreset>[
  // vivid (구 partColorPresets)
  ColorPreset(id: 'cp_red',     name: '빨강', argb: 0xFFEF4444),
  ColorPreset(id: 'cp_orange',  name: '주황', argb: 0xFFF97316),
  ColorPreset(id: 'cp_yellow',  name: '황색', argb: 0xFFEAB308),
  ColorPreset(id: 'cp_lime',    name: '연두', argb: 0xFF84CC16),
  ColorPreset(id: 'cp_green',   name: '초록', argb: 0xFF16A34A),
  ColorPreset(id: 'cp_teal',    name: '청록', argb: 0xFF14B8A6),
  ColorPreset(id: 'cp_sky',     name: '하늘', argb: 0xFF0EA5E9),
  ColorPreset(id: 'cp_blue',    name: '남색', argb: 0xFF3B82F6),
  ColorPreset(id: 'cp_purple',  name: '보라', argb: 0xFF8B5CF6),
  ColorPreset(id: 'cp_magenta', name: '자홍', argb: 0xFFD946EF),
  ColorPreset(id: 'cp_pink',    name: '분홍', argb: 0xFFEC4899),
  ColorPreset(id: 'cp_crimson', name: '진홍', argb: 0xFFBE123C),
  // wood-tone (구 stockColorPresets)
  ColorPreset(id: 'cp_birch',     name: '자작',     argb: 0xFFFAF1DC),
  ColorPreset(id: 'cp_maple',     name: '단풍',     argb: 0xFFE8D2A6),
  ColorPreset(id: 'cp_beige',     name: '베이지',   argb: 0xFFD4B896),
  ColorPreset(id: 'cp_pine',      name: '솔송',     argb: 0xFFC9A876),
  ColorPreset(id: 'cp_oak',       name: '적참',     argb: 0xFFB8865C),
  ColorPreset(id: 'cp_walnut',    name: '호두',     argb: 0xFF8B6240),
  ColorPreset(id: 'cp_ebony',     name: '흑단',     argb: 0xFF3D2A1E),
  ColorPreset(id: 'cp_white_mel', name: '백색멜라민', argb: 0xFFF7F7F2),
  ColorPreset(id: 'cp_lt_gray',   name: '연회색',   argb: 0xFFD4D4D4),
  ColorPreset(id: 'cp_mdf_gray',  name: '회색MDF',  argb: 0xFFA8A29E),
  ColorPreset(id: 'cp_dk_gray',   name: '진회색',   argb: 0xFF6B6B6B),
  ColorPreset(id: 'cp_black_mel', name: '검정멜라민', argb: 0xFF262626),
];

const seedPartPresets = <DimensionPreset>[];

const seedStockPresets = <DimensionPreset>[
  DimensionPreset(id: 'sp_ply12_h',   length: 2440, width: 1220, label: '12T 합판',
      colorPresetId: null, grain: GrainDirection.none),
  DimensionPreset(id: 'sp_ply12_v',   length: 1220, width: 2440, label: '12T 합판 가로',
      colorPresetId: null, grain: GrainDirection.none),
  DimensionPreset(id: 'sp_ply15',     length: 2440, width: 1220, label: '15T 합판',
      colorPresetId: null, grain: GrainDirection.none),
  DimensionPreset(id: 'sp_ply18',     length: 2440, width: 1220, label: '18T 합판',
      colorPresetId: null, grain: GrainDirection.none),
  DimensionPreset(id: 'sp_mdf9',      length: 2440, width: 1220, label: 'MDF 9T',
      colorPresetId: null, grain: GrainDirection.none),
  DimensionPreset(id: 'sp_mdf18',     length: 2440, width: 1220, label: 'MDF 18T',
      colorPresetId: null, grain: GrainDirection.none),
];
```

**Step 4: 통과 확인**

**Step 5: 커밋**

```bash
git add lib/data/preset/preset_seeds.dart \
        test/data/preset/preset_seeds_test.dart
git commit -m "feat(preset): seed 24 colors + 6 stock presets, 0 part presets"
```

---

### Task 4: PresetRepository — JSON I/O

**Files:**
- Create: `lib/data/preset/preset_repository.dart`
- Test: `test/data/preset/preset_repository_test.dart`

**Step 1: 실패하는 테스트** (`Directory.systemTemp` 패턴, `project_file_test.dart`와 동일):

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/data/preset/preset_seeds.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cm_preset_test_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('load on missing file returns seeds', () async {
    final repo = PresetRepository(filePath: p.join(tmp.path, 'presets.json'));
    final state = await repo.load();
    expect(state.colors, seedColorPresets);
    expect(state.stocks, seedStockPresets);
    expect(state.parts, isEmpty);
  });

  test('save creates file and load round-trips', () async {
    final repo = PresetRepository(filePath: p.join(tmp.path, 'presets.json'));
    final added = ColorPreset(id: 'cp_custom', name: '내색', argb: 0xFF112233);
    final state = PresetState(
      colors: [...seedColorPresets, added],
      parts: const [],
      stocks: seedStockPresets,
    );
    await repo.save(state);

    final repo2 = PresetRepository(filePath: p.join(tmp.path, 'presets.json'));
    final loaded = await repo2.load();
    expect(loaded.colors.last, added);
  });

  test('load on corrupt JSON falls back to seeds', () async {
    final path = p.join(tmp.path, 'presets.json');
    File(path).writeAsStringSync('{not json');
    final repo = PresetRepository(filePath: path);
    final state = await repo.load();
    expect(state.colors, seedColorPresets); // fallback
  });
}
```

**Step 2: 실패 확인**

**Step 3: 구현**

`lib/data/preset/preset_repository.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'preset_models.dart';
import 'preset_seeds.dart';

class PresetState {
  final List<ColorPreset> colors;
  final List<DimensionPreset> parts;
  final List<DimensionPreset> stocks;
  const PresetState({
    required this.colors,
    required this.parts,
    required this.stocks,
  });

  static const seeded = PresetState(
    colors: seedColorPresets,
    parts: seedPartPresets,
    stocks: seedStockPresets,
  );
}

class PresetRepository {
  PresetRepository({String? filePath}) : _explicitPath = filePath;
  final String? _explicitPath;

  static const _version = 1;

  Future<String> _resolvePath() async {
    if (_explicitPath != null) return _explicitPath!;
    final dir = await getApplicationSupportDirectory();
    final cm = Directory(p.join(dir.path));
    if (!cm.existsSync()) cm.createSync(recursive: true);
    return p.join(cm.path, 'presets.json');
  }

  Future<PresetState> load() async {
    final path = await _resolvePath();
    final f = File(path);
    if (!f.existsSync()) return PresetState.seeded;
    try {
      final raw = await f.readAsString();
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return PresetState(
        colors: (j['colorPresets'] as List? ?? [])
            .map((e) => ColorPreset.fromJson(e as Map<String, dynamic>))
            .toList(),
        parts: (j['partPresets'] as List? ?? [])
            .map((e) => DimensionPreset.fromJson(e as Map<String, dynamic>))
            .toList(),
        stocks: (j['stockPresets'] as List? ?? [])
            .map((e) => DimensionPreset.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return PresetState.seeded;
    }
  }

  Future<void> save(PresetState s) async {
    final path = await _resolvePath();
    final tmp = '$path.tmp';
    final body = const JsonEncoder.withIndent('  ').convert({
      'version': _version,
      'colorPresets': s.colors.map((c) => c.toJson()).toList(),
      'partPresets': s.parts.map((p) => p.toJson()).toList(),
      'stockPresets': s.stocks.map((p) => p.toJson()).toList(),
    });
    await File(tmp).writeAsString(body, flush: true);
    await File(tmp).rename(path);
  }
}
```

**Step 4: 통과 확인**

**Step 5: 커밋**

```bash
git add lib/data/preset/preset_repository.dart \
        test/data/preset/preset_repository_test.dart
git commit -m "feat(preset): PresetRepository load/save with seed fallback"
```

---

### Task 5: Riverpod provider (`PresetsNotifier`)

**Files:**
- Create: `lib/ui/providers/preset_provider.dart`
- Test: `test/ui/providers/preset_provider_test.dart`

**Step 1: 실패하는 테스트** — provider가 load한 후 색상 추가/수정/삭제 가능, save 호출 확인.

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart' show GrainDirection;

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cm_pp_test_');
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('addColor / updateColor / removeColor persist to disk', () async {
    final path = p.join(tmp.path, 'presets.json');
    final repo = PresetRepository(filePath: path);
    final notifier = PresetsNotifier(repo);
    await notifier.load();

    final initialLen = notifier.state.colors.length;
    final added = ColorPreset(id: 'cp_x', name: '내색', argb: 0xFF112233);
    await notifier.addColor(added);
    expect(notifier.state.colors.length, initialLen + 1);

    await notifier.updateColor(
        added.copyWith(name: '내색2', argb: 0xFF445566));
    expect(notifier.state.colors.last.name, '내색2');

    await notifier.removeColor('cp_x');
    expect(notifier.state.colors.length, initialLen);

    final reloaded = await PresetRepository(filePath: path).load();
    expect(reloaded.colors.length, initialLen);
  });

  test('removeColor cascades colorPresetId=null on stock/part presets', () async {
    final path = p.join(tmp.path, 'presets.json');
    final repo = PresetRepository(filePath: path);
    final notifier = PresetsNotifier(repo);
    await notifier.load();

    final c = ColorPreset(id: 'cp_y', name: '연두색', argb: 0xFF00FF00);
    await notifier.addColor(c);
    await notifier.addStockPreset(DimensionPreset(
      id: 'sp_test', length: 100, width: 50, label: 'A',
      colorPresetId: 'cp_y', grain: GrainDirection.none,
    ));
    await notifier.removeColor('cp_y');
    final s = notifier.state.stocks.firstWhere((x) => x.id == 'sp_test');
    expect(s.colorPresetId, isNull);
  });
}
```

**Step 2: 실패 확인**

**Step 3: 구현**

`lib/ui/providers/preset_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/preset/preset_models.dart';
import '../../data/preset/preset_repository.dart';

extension on ColorPreset {
  ColorPreset copyWith({String? name, int? argb}) =>
      ColorPreset(id: id, name: name ?? this.name, argb: argb ?? this.argb);
}

class PresetsNotifier extends ChangeNotifier {
  PresetsNotifier(this._repo);
  final PresetRepository _repo;
  PresetState _state = PresetState.seeded;
  PresetState get state => _state;

  Future<void> load() async {
    _state = await _repo.load();
    notifyListeners();
  }

  Future<void> _persist() => _repo.save(_state);

  // ===== ColorPreset =====
  Future<void> addColor(ColorPreset c) async {
    _state = PresetState(
      colors: [..._state.colors, c],
      parts: _state.parts,
      stocks: _state.stocks,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> updateColor(ColorPreset c) async {
    _state = PresetState(
      colors: _state.colors.map((e) => e.id == c.id ? c : e).toList(),
      parts: _state.parts,
      stocks: _state.stocks,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> removeColor(String id) async {
    DimensionPreset clearIfMatch(DimensionPreset d) =>
        d.colorPresetId == id
            ? DimensionPreset(
                id: d.id, length: d.length, width: d.width,
                label: d.label, colorPresetId: null, grain: d.grain)
            : d;
    _state = PresetState(
      colors: _state.colors.where((e) => e.id != id).toList(),
      parts: _state.parts.map(clearIfMatch).toList(),
      stocks: _state.stocks.map(clearIfMatch).toList(),
    );
    notifyListeners();
    await _persist();
  }

  // ===== Part / Stock DimensionPreset =====
  Future<void> addPartPreset(DimensionPreset d) async {
    _state = PresetState(colors: _state.colors,
        parts: [..._state.parts, d], stocks: _state.stocks);
    notifyListeners(); await _persist();
  }
  Future<void> updatePartPreset(DimensionPreset d) async {
    _state = PresetState(colors: _state.colors,
        parts: _state.parts.map((e) => e.id == d.id ? d : e).toList(),
        stocks: _state.stocks);
    notifyListeners(); await _persist();
  }
  Future<void> removePartPreset(String id) async {
    _state = PresetState(colors: _state.colors,
        parts: _state.parts.where((e) => e.id != id).toList(),
        stocks: _state.stocks);
    notifyListeners(); await _persist();
  }
  Future<void> addStockPreset(DimensionPreset d) async {
    _state = PresetState(colors: _state.colors, parts: _state.parts,
        stocks: [..._state.stocks, d]);
    notifyListeners(); await _persist();
  }
  Future<void> updateStockPreset(DimensionPreset d) async {
    _state = PresetState(colors: _state.colors, parts: _state.parts,
        stocks: _state.stocks.map((e) => e.id == d.id ? d : e).toList());
    notifyListeners(); await _persist();
  }
  Future<void> removeStockPreset(String id) async {
    _state = PresetState(colors: _state.colors, parts: _state.parts,
        stocks: _state.stocks.where((e) => e.id != id).toList());
    notifyListeners(); await _persist();
  }

  // Lookup helper
  ColorPreset? colorById(String? id) {
    if (id == null) return null;
    for (final c in _state.colors) {
      if (c.id == id) return c;
    }
    return null;
  }
}

final presetsProvider =
    ChangeNotifierProvider<PresetsNotifier>((ref) {
  throw UnimplementedError('main()에서 override 됨');
});
```

`main.dart`에서 `presetsProvider` override 하고 앱 시작 시 `load()` 호출 — Task 21에서 wiring.

**Step 4: 통과 확인**

**Step 5: 커밋**

```bash
git add lib/ui/providers/preset_provider.dart \
        test/ui/providers/preset_provider_test.dart
git commit -m "feat(preset): PresetsNotifier with cascade-on-color-delete"
```

---

## Phase B — 모델 마이그레이션

### Task 6: CutPart `colorArgb` → `colorPresetId`

**Files:**
- Modify: `lib/domain/models/cut_part.dart`
- Modify: `test/domain/models/` (필요 시)

**Step 1: 실패하는 테스트** — `test/domain/models/cut_part_migration_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/cut_part.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';

void main() {
  test('legacy color (int ARGB) maps to colorPresetId via matcher', () {
    final j = {
      'id': 'p1',
      'length': 600.0,
      'width': 300.0,
      'qty': 1,
      'label': '',
      'grain': 'none',
      'color': 0xFFEF4444, // legacy 빨강
    };
    final p = CutPart.fromJson(j, colorMatcher: (argb) {
      expect(argb, 0xFFEF4444);
      return 'cp_red';
    });
    expect(p.colorPresetId, 'cp_red');
  });

  test('new colorPresetId field is preferred over legacy', () {
    final j = {
      'id': 'p1', 'length': 600.0, 'width': 300.0, 'qty': 1,
      'label': '', 'grain': 'none',
      'colorPresetId': 'cp_walnut',
    };
    final p = CutPart.fromJson(j, colorMatcher: (_) => 'wrong');
    expect(p.colorPresetId, 'cp_walnut');
  });

  test('null color stays null (자동)', () {
    final j = {
      'id': 'p1', 'length': 600.0, 'width': 300.0, 'qty': 1,
      'label': '', 'grain': 'none',
    };
    final p = CutPart.fromJson(j, colorMatcher: (_) => 'never');
    expect(p.colorPresetId, isNull);
  });
}
```

**Step 2: 실패 확인**

**Step 3: 구현** — `lib/domain/models/cut_part.dart` 변경:

```dart
import 'stock_sheet.dart' show GrainDirection;

class CutPart {
  final String id;
  final double length;
  final double width;
  final int qty;
  final String label;
  final GrainDirection grainDirection;
  final String? colorPresetId;

  const CutPart({
    required this.id,
    required this.length,
    required this.width,
    required this.qty,
    this.label = '',
    this.grainDirection = GrainDirection.none,
    this.colorPresetId,
  });

  CutPart copyWith({
    String? id, double? length, double? width, int? qty, String? label,
    GrainDirection? grainDirection, String? colorPresetId,
    bool clearColor = false,
  }) =>
      CutPart(
        id: id ?? this.id,
        length: length ?? this.length,
        width: width ?? this.width,
        qty: qty ?? this.qty,
        label: label ?? this.label,
        grainDirection: grainDirection ?? this.grainDirection,
        colorPresetId: clearColor ? null : (colorPresetId ?? this.colorPresetId),
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'length': length, 'width': width, 'qty': qty,
        'label': label, 'grain': grainDirection.name,
        if (colorPresetId != null) 'colorPresetId': colorPresetId,
      };

  /// fromJson는 마이그레이션을 위해 [colorMatcher]를 받는다 — 옛 `color: int`
  /// 필드가 보이면 매칭되는 ColorPreset.id를 반환할 책임이 호출자에게 있다.
  factory CutPart.fromJson(
    Map<String, dynamic> j, {
    String? Function(int argb)? colorMatcher,
  }) {
    String? cpid = j['colorPresetId'] as String?;
    if (cpid == null && j['color'] is int && colorMatcher != null) {
      cpid = colorMatcher(j['color'] as int);
    }
    return CutPart(
      id: j['id'] as String,
      length: (j['length'] as num).toDouble(),
      width: (j['width'] as num).toDouble(),
      qty: j['qty'] as int,
      label: (j['label'] as String?) ?? '',
      grainDirection:
          GrainDirection.values.byName((j['grain'] as String?) ?? 'none'),
      colorPresetId: cpid,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CutPart && other.id == id && other.length == length &&
      other.width == width && other.qty == qty && other.label == label &&
      other.grainDirection == grainDirection &&
      other.colorPresetId == colorPresetId;

  @override
  int get hashCode =>
      Object.hash(id, length, width, qty, label, grainDirection, colorPresetId);
}
```

**Step 4: 통과 확인** — `flutter test test/domain/models/cut_part_migration_test.dart`

**중요:** 이 변경은 다른 파일을 깨뜨립니다. 다음 단계로 즉시 진행.

**Step 5: 커밋 보류** — Task 7과 함께 묶어서 커밋(StockSheet도 같이 바꿔야 build pass).

---

### Task 7: StockSheet 동일 변경 + 호출처 수정

**Files:**
- Modify: `lib/domain/models/stock_sheet.dart`
- Modify: `lib/ui/widgets/parts_table.dart` (`p.copyWith(colorArgb:)` 호출)
- Modify: `lib/ui/widgets/stocks_table.dart` (`s.copyWith(colorArgb:)` 호출)
- Modify: `lib/ui/widgets/color_swatch_button.dart` (만약 colorArgb 직접 참조 있으면)

**Step 1: StockSheet 변경** — `CutPart`와 같은 패턴으로 `colorArgb` →
`colorPresetId` + `colorMatcher` 파라미터.

**Step 2: 호출처 수정** — `parts_table.dart`/`stocks_table.dart`의
`onChanged` 콜백 안에서 `colorArgb` 참조를 일단 `colorPresetId`로
이름만 바꿈 (실제 값은 Task 11에서 색상 picker 흐름이 새 모델 쓰면서
정합성 맞춰짐).

**Step 3: 컴파일 통과 확인**

```bash
flutter analyze
```

Expected: 색상 관련 에러 모두 해결.

**Step 4: 기존 테스트 통과 확인**

```bash
flutter test
```

Expected: legacy 마이그레이션 테스트 + Phase A 테스트 모두 PASS. 위젯
테스트 일부는 후속 Task에서 같이 고침 (color picker / preset dialog
변경에 의존).

**Step 5: 커밋**

```bash
git add lib/domain/models/cut_part.dart lib/domain/models/stock_sheet.dart \
        lib/ui/widgets/parts_table.dart lib/ui/widgets/stocks_table.dart \
        test/domain/models/
git commit -m "refactor(model): CutPart/StockSheet colorArgb → colorPresetId"
```

---

### Task 8: Project schemaVersion 1 → 2 + colorMatcher 주입

**Files:**
- Modify: `lib/domain/models/project.dart`
- Modify: `lib/data/file/project_file.dart`
- Test: `test/data/file/legacy_color_migration_test.dart` (신규)

**Step 1: 실패하는 테스트** — 옛 schemaVersion=1 (`color: int` 포함)
파일을 읽으면 `colorPresetId`로 매핑.

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cutmaster/data/file/project_file.dart';

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cm_legacy_');
  });
  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('legacy v1 file with color:int gets colorPresetId via matcher', () async {
    final path = p.join(tmp.path, 'old.cutmaster');
    File(path).writeAsStringSync(jsonEncode({
      'schemaVersion': 1,
      'id': 'a', 'name': '책장', 'kerf': 3.0,
      'grainLocked': false, 'showPartLabels': true, 'useSingleSheet': false,
      'createdAt': '2024-01-01T00:00:00.000',
      'updatedAt': '2024-01-01T00:00:00.000',
      'parts': [{
        'id': 'p1', 'length': 600.0, 'width': 300.0, 'qty': 1,
        'label': '', 'grain': 'none', 'color': 0xFFEF4444,
      }],
      'stocks': [],
    }));

    final svc = ProjectFileService(
      colorMatcher: (argb) => argb == 0xFFEF4444 ? 'cp_red' : null,
    );
    final loaded = await svc.read(path);
    expect(loaded.parts.first.colorPresetId, 'cp_red');
  });
}
```

**Step 2: 실패 확인**

**Step 3: 구현**

`Project.fromJson`이 colorMatcher를 받도록 변경:

```dart
factory Project.fromJson(
  Map<String, dynamic> j, {
  String? Function(int argb)? colorMatcher,
}) {
  final v = j['schemaVersion'] as int? ?? 1;
  if (v > schemaVersion) {
    throw FormatException('Unsupported schemaVersion: $v');
  }
  return Project(
    id: j['id'] as String, name: j['name'] as String,
    stocks: ((j['stocks'] as List?) ?? const [])
        .map((e) => StockSheet.fromJson(e as Map<String, dynamic>,
            colorMatcher: colorMatcher))
        .toList(),
    parts: ((j['parts'] as List?) ?? const [])
        .map((e) => CutPart.fromJson(e as Map<String, dynamic>,
            colorMatcher: colorMatcher))
        .toList(),
    // ...rest unchanged
  );
}

static const int schemaVersion = 2;
```

`ProjectFileService` 생성자에 `colorMatcher` 파라미터 추가:

```dart
class ProjectFileService {
  ProjectFileService({this.colorMatcher});
  final String? Function(int argb)? colorMatcher;

  Future<Project> read(String path) async {
    final raw = await File(path).readAsString();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return Project.fromJson(j, colorMatcher: colorMatcher);
  }
  // ...
}
```

**Step 4: 통과 확인** — 마이그레이션 테스트 + 기존 `project_file_test.dart` 전체 PASS.

**Step 5: 커밋**

```bash
git add lib/domain/models/project.dart lib/data/file/project_file.dart \
        test/data/file/legacy_color_migration_test.dart
git commit -m "feat(io): legacy color:int → colorPresetId migration via colorMatcher"
```

---

### Task 9: ColorMatcher 헬퍼 — 가장 가까운 색상 프리셋 매칭

**Files:**
- Create: `lib/data/preset/color_matcher.dart`
- Test: `test/data/preset/color_matcher_test.dart`

**Step 1: 실패하는 테스트**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/data/preset/color_matcher.dart';
import 'package:cutmaster/data/preset/preset_seeds.dart';

void main() {
  test('exact match returns preset id', () {
    final m = ColorMatcher(seedColorPresets);
    expect(m.match(0xFFEF4444), 'cp_red'); // 빨강 정확 매칭
  });

  test('near match returns nearest by RGB distance', () {
    final m = ColorMatcher(seedColorPresets);
    // 빨강(0xFFEF4444) 근처 — distance < threshold면 cp_red 반환
    expect(m.match(0xFFEE4343), 'cp_red');
  });

  test('far color returns null (caller can auto-create)', () {
    final m = ColorMatcher(seedColorPresets);
    // 시드와 모두 멀리 떨어진 색
    expect(m.match(0xFF7B7B00), isNull);
  });
}
```

**Step 2: 실패 확인**

**Step 3: 구현**

```dart
import 'preset_models.dart';

class ColorMatcher {
  ColorMatcher(this.colors, {this.maxDistance = 30.0});
  final List<ColorPreset> colors;
  final double maxDistance;

  /// argb의 가장 가까운 ColorPreset.id 반환. threshold 초과면 null.
  String? match(int argb) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    String? bestId;
    double bestDist = double.infinity;
    for (final c in colors) {
      final pr = (c.argb >> 16) & 0xFF;
      final pg = (c.argb >> 8) & 0xFF;
      final pb = c.argb & 0xFF;
      final dr = (r - pr).toDouble();
      final dg = (g - pg).toDouble();
      final db = (b - pb).toDouble();
      final d = (dr * dr + dg * dg + db * db); // squared
      if (d < bestDist) {
        bestDist = d;
        bestId = c.id;
      }
    }
    final dist = bestDist.isFinite ? bestDist : double.infinity;
    // sqrt 비교 대신 maxDistance^2 와 비교 — 미세 최적화
    if (dist > maxDistance * maxDistance) return null;
    return bestId;
  }
}
```

**Step 4: 통과 확인**

**Step 5: 커밋**

```bash
git add lib/data/preset/color_matcher.dart \
        test/data/preset/color_matcher_test.dart
git commit -m "feat(preset): ColorMatcher (closest by RGB distance, threshold)"
```

---

## Phase C — UI: 색상 프리셋 관리

### Task 10: `flutter_colorpicker` 의존성 + ColorPresetManagementDialog

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/ui/widgets/color_preset_management_dialog.dart`
- Test: `test/ui/widgets/color_preset_management_dialog_test.dart`

**Step 1: pubspec에 추가**

```yaml
dependencies:
  flutter_colorpicker: ^1.1.0
```

Run: `flutter pub get`

**Step 2: 실패하는 위젯 테스트**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cutmaster/data/preset/preset_models.dart';
import 'package:cutmaster/data/preset/preset_repository.dart';
import 'package:cutmaster/ui/providers/preset_provider.dart';
import 'package:cutmaster/ui/widgets/color_preset_management_dialog.dart';

class _FakeRepo extends PresetRepository {
  _FakeRepo() : super(filePath: '/dev/null/x');
  @override
  Future<PresetState> load() async => PresetState.seeded;
  @override
  Future<void> save(PresetState s) async {}
}

void main() {
  testWidgets('shows list of seed colors', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: const MaterialApp(home: ColorPresetManagementDialog()),
    ));
    expect(find.text('호두'), findsOneWidget);
    expect(find.text('빨강'), findsOneWidget);
  });

  testWidgets('add button creates new color and selects it', (tester) async {
    final notifier = PresetsNotifier(_FakeRepo());
    await notifier.load();
    final initialLen = notifier.state.colors.length;
    await tester.pumpWidget(ProviderScope(
      overrides: [presetsProvider.overrideWith((_) => notifier)],
      child: const MaterialApp(home: ColorPresetManagementDialog()),
    ));
    await tester.tap(find.byTooltip('추가'));
    await tester.pumpAndSettle();
    expect(notifier.state.colors.length, initialLen + 1);
  });
}
```

**Step 3: 실패 확인**

**Step 4: 구현** — 좌측 ListView (이름) + 우측 폼 (이름 TextField + 색상 swatch).
swatch 클릭 시 `flutter_colorpicker`의 `BlockPicker` sub-dialog. 변경은
300ms 디바운스 후 `notifier.updateColor()` 호출.

(전체 코드 ~150줄 — 패턴이 정해진 후 implementation 단계에서 작성.)

**Step 5: 통과 확인**

**Step 6: 커밋**

```bash
git add pubspec.yaml pubspec.lock \
        lib/ui/widgets/color_preset_management_dialog.dart \
        test/ui/widgets/color_preset_management_dialog_test.dart
git commit -m "feat(ui): ColorPresetManagementDialog (list + form + flutter_colorpicker)"
```

---

### Task 11: 색상 picker dialog 글로벌 풀로 hookup

**Files:**
- Modify: `lib/ui/widgets/color_picker_dialog.dart`
- Modify: `lib/ui/widgets/color_swatch_button.dart`
- Modify: `lib/ui/utils/part_color.dart` (presetsFor 제거 또는 글로벌 lookup)
- Test: `test/ui/widgets/color_picker_dialog_test.dart` 갱신

**Step 1: 위젯 시그니처 변경**

`showColorPickerDialog`가 `ColorPalette` 대신 글로벌 색상 프리셋을 직접
사용. 결과 타입을 `ColorChoice` 그대로 두되 의미를:
- `ColorChoice.auto` → `colorPresetId = null`
- `ColorChoice.value(presetId)` → `colorPresetId = presetId`

(int argb 대신 String presetId.)

**Step 2: 다이얼로그 하단에 "색상 프리셋 관리..." 버튼 추가** —
누르면 `ColorPresetManagementDialog` 띄움 (현재 다이얼로그는 그대로 유지).

**Step 3: ColorSwatchButton 호출처 수정**

- `parts_table.dart`: `p.copyWith(colorPresetId: ...)` 흐름.
- `stocks_table.dart`: 동일.

**Step 4: utils/part_color.dart 정리**

- `presetsFor()` 제거 (글로벌 provider로 lookup).
- `presetNameOf(int argb)` → `presetNameById(String? id, PresetsNotifier)` 로 변경.
- `autoColorFor(id, palette)` 유지 (자동 색 fallback). 단 `ColorPalette` enum
  은 더 이상 의미 없으니 제거 또는 deprecation. 제거가 깔끔.

**Step 5: 분석 + 테스트 통과**

```bash
flutter analyze && flutter test
```

**Step 6: 커밋**

```bash
git add lib/ui/widgets/color_picker_dialog.dart \
        lib/ui/widgets/color_swatch_button.dart \
        lib/ui/utils/part_color.dart \
        lib/ui/widgets/parts_table.dart lib/ui/widgets/stocks_table.dart \
        test/ui/widgets/color_picker_dialog_test.dart
git commit -m "feat(ui): color picker uses global ColorPresets, drop ColorPalette enum"
```

---

## Phase D — UI: 부품/자재 프리셋 관리

### Task 12: PresetManagementDialog (부품/자재 공용)

**Files:**
- Create: `lib/ui/widgets/preset_management_dialog.dart`
- Test: `test/ui/widgets/preset_management_dialog_test.dart`

**Step 1: 시그니처**

```dart
enum PresetKind { part, stock }

Future<void> showPresetManagementDialog(BuildContext context, PresetKind kind);
```

내부적으로 `PresetKind`에 따라 `notifier.state.parts` 또는 `state.stocks`를
보여주고, add/update/remove도 분기.

**Step 2: 위젯 테스트** — 시드 자재 6종이 보이고, 새 프리셋 추가 시 리스트에 반영.

**Step 3: 구현** — 좌측 ListView + 우측 폼 (라벨/길이/폭/색상 드롭다운/결방향 segmented).
색상 드롭다운 하단에 "색상 프리셋 관리..." 진입점.

**Step 4: 테스트 통과**

**Step 5: 커밋**

```bash
git add lib/ui/widgets/preset_management_dialog.dart \
        test/ui/widgets/preset_management_dialog_test.dart
git commit -m "feat(ui): PresetManagementDialog for part/stock dimension presets"
```

---

### Task 13: preset_dialog (선택용) hookup + "관리..." 버튼

**Files:**
- Modify: `lib/ui/widgets/preset_dialog.dart`

**Step 1:** 하드코딩 `_presets` 제거. `PresetKind` 인자 추가, provider에서
프리셋 풀 가져옴. 다이얼로그 하단에 "프리셋 관리..." 버튼 추가 →
`showPresetManagementDialog(context, kind)` 호출.

**Step 2: 분석 + 위젯 테스트 갱신**

**Step 3: 커밋**

```bash
git add lib/ui/widgets/preset_dialog.dart
git commit -m "feat(ui): preset selector reads global presets + 'manage' entry"
```

---

### Task 14: 부품 테이블에 "프리셋" 버튼 추가

**Files:**
- Modify: `lib/ui/widgets/parts_table.dart`

**Step 1:** `stocks_table.dart`의 OutlinedButton.icon 패턴을 그대로 부품에도 추가.
`PresetKind.part`로 호출.

**Step 2: 분석 + 빌드**

**Step 3: 커밋**

```bash
git add lib/ui/widgets/parts_table.dart
git commit -m "feat(ui): part table gets '프리셋' button (parity with stocks)"
```

---

## Phase E — UI: 행 레이아웃 재구성

### Task 15: QtyStepper 위젯

**Files:**
- Create: `lib/ui/widgets/qty_stepper.dart`
- Test: `test/ui/widgets/qty_stepper_test.dart`

**Step 1: 실패하는 위젯 테스트**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/ui/widgets/qty_stepper.dart';

void main() {
  testWidgets('+ button increments by 1', (tester) async {
    int v = 3;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      StatefulBuilder(builder: (ctx, setState) => QtyStepper(
        value: v, onChanged: (n) => setState(() => v = n),
      )))));
    await tester.tap(find.byTooltip('증가'));
    await tester.pumpAndSettle();
    expect(v, 4);
  });

  testWidgets('- below 1 clamps to 1', (tester) async {
    int v = 1;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      StatefulBuilder(builder: (ctx, setState) => QtyStepper(
        value: v, onChanged: (n) => setState(() => v = n),
      )))));
    await tester.tap(find.byTooltip('감소'));
    await tester.pumpAndSettle();
    expect(v, 1);
  });

  testWidgets('typing 0 clamps to 1 on commit', (tester) async {
    int v = 5;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      StatefulBuilder(builder: (ctx, setState) => QtyStepper(
        value: v, onChanged: (n) => setState(() => v = n),
      )))));
    await tester.enterText(find.byType(TextField), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(v, 1);
  });
}
```

**Step 2: 실패 확인**

**Step 3: 구현**

```dart
import 'package:flutter/material.dart';

class QtyStepper extends StatefulWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged,
      this.min = 1, this.max = 999});
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  State<QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<QtyStepper> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(QtyStepper old) {
    super.didUpdateWidget(old);
    if (widget.value.toString() != _ctrl.text) {
      _ctrl.text = widget.value.toString();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _emit(int n) {
    final clamped = n.clamp(widget.min, widget.max);
    if (_ctrl.text != clamped.toString()) {
      _ctrl.text = clamped.toString();
    }
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80, height: 28,
      child: Row(children: [
        SizedBox(width: 24, height: 28, child: IconButton(
          tooltip: '감소', padding: EdgeInsets.zero,
          icon: const Icon(Icons.remove, size: 14),
          onPressed: () => _emit(widget.value - 1),
        )),
        Expanded(child: TextField(
          controller: _ctrl, textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 2),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (s) => _emit(int.tryParse(s) ?? widget.min),
          onEditingComplete: () =>
              _emit(int.tryParse(_ctrl.text) ?? widget.min),
        )),
        SizedBox(width: 24, height: 28, child: IconButton(
          tooltip: '증가', padding: EdgeInsets.zero,
          icon: const Icon(Icons.add, size: 14),
          onPressed: () => _emit(widget.value + 1),
        )),
      ]),
    );
  }
}
```

**Step 4: 통과 확인**

**Step 5: 커밋**

```bash
git add lib/ui/widgets/qty_stepper.dart \
        test/ui/widgets/qty_stepper_test.dart
git commit -m "feat(ui): QtyStepper [-][n][+] inline widget with clamp"
```

---

### Task 16: EditableDimensionTable 1줄+메타 줄 재구성

**Files:**
- Modify: `lib/ui/widgets/editable_dimension_table.dart`
- Test: `test/ui/widgets/editable_dimension_table_test.dart`

**Step 1: 위젯 테스트** — 한 행에 색상 swatch + 길이 + 폭 + QtyStepper +
메타 줄(색상 이름 텍스트, 결방향 아이콘, 라벨)이 있는지.

**Step 2: 구현**

- 각 행을 두 줄 Column으로 변경.
  - 1줄: `[swatch (28)] [len (Expanded 2)] × [wid (Expanded 2)] [QtyStepper (80)] [✕ (28)]`
  - 메타 줄: `[색상 이름] · [결방향 아이콘] · [라벨 (인라인 편집)]`
- `EditableRow`에 `colorPresetId`, `grain` 필드 추가.
- `leadingBuilder` API는 swatch 자리에 그대로 사용 (호출처는 ColorSwatchButton).
- 메타 줄에 표시할 색상 이름은 `PresetsNotifier.colorById(id)?.name ?? '자동'` 패턴.
  자동이면 italic + textSecondary, 프리셋이면 textPrimary.
- 결방향 아이콘: `↔`(`Icons.swap_horiz`) / `↕`(`Icons.swap_vert`) / 표시 안 함.
- 라벨: 메타 줄 inline `Text` + tap → `TextField` 변환 → onSubmitted/blur로 commit.

**Step 3: 헤더 단순화** — `[길이]   [폭]   수량` 만, 라벨 헤더 제거.

**Step 4: 통과 확인 + 분석**

**Step 5: 커밋**

```bash
git add lib/ui/widgets/editable_dimension_table.dart \
        test/ui/widgets/editable_dimension_table_test.dart
git commit -m "feat(ui): row layout — 1줄 edit + meta row (color name / grain / label)"
```

---

### Task 17: parts_table / stocks_table 메타 정보 wiring

**Files:**
- Modify: `lib/ui/widgets/parts_table.dart`
- Modify: `lib/ui/widgets/stocks_table.dart`

**Step 1:** `EditableRow` 매핑할 때 `colorPresetId` 와 `grain` 도 같이 넘기고
`onChanged` 콜백에서 받음. `presetsProvider.colorById`로 메타 줄 이름 lookup.

**Step 2: 분석 + 테스트 통과**

**Step 3: 커밋**

```bash
git add lib/ui/widgets/parts_table.dart lib/ui/widgets/stocks_table.dart
git commit -m "feat(ui): wire colorPresetId/grain through Parts/StocksTable rows"
```

---

## Phase F — 진입점 wiring

### Task 18: LeftPane 섹션 헤더 ⚙️ 아이콘

**Files:**
- Modify: `lib/ui/widgets/left_pane.dart`

**Step 1:** `_Section` 헤더 Row 우측에 `IconButton(Icons.settings, size: 14)`
추가 — Part 섹션이면 `showPresetManagementDialog(ctx, PresetKind.part)`,
Stock 섹션이면 `PresetKind.stock`. Options 섹션은 ⚙️ 안 표시.

**Step 2: 위젯 테스트** — 헤더에 settings 버튼이 있고 누르면 다이얼로그 열림.

**Step 3: 통과 확인**

**Step 4: 커밋**

```bash
git add lib/ui/widgets/left_pane.dart \
        test/ui/widgets/left_pane_test.dart
git commit -m "feat(ui): left pane section header gets ⚙️ for preset management"
```

---

### Task 19: main.dart에서 PresetsNotifier override + 앱 부팅 시 load

**Files:**
- Modify: `lib/main.dart`

**Step 1:** `PresetRepository`를 만들고 `PresetsNotifier`를 생성, `load()` 호출 후 `presetsProvider`를 override 하는 흐름. `runApp` 전에 `WidgetsFlutterBinding.ensureInitialized()` + `await notifier.load()`.

**Step 2:** `ProjectFileService` 생성 시 `colorMatcher`를 주입. matcher는 `ColorMatcher(notifier.state.colors).match` 람다 — provider 변경 시점은 상관없음(매핑은 read 시점).

**Step 3: 분석 + integration_test 부팅 확인**

**Step 4: 커밋**

```bash
git add lib/main.dart
git commit -m "feat(boot): load PresetsNotifier + inject colorMatcher into ProjectFileService"
```

---

## Phase G — E2E

### Task 20: 마이그레이션 시나리오 integration_test

**Files:**
- Create: `integration_test/preset_migration_test.dart`

**Step 1:** 시나리오:
1. tmp 디렉터리에 옛 schemaVersion=1 .cutmaster 파일 (`color: 0xFFEF4444`) 생성.
2. 앱 실행, 그 파일 열기.
3. 부품 행의 색상 swatch가 빨강(`cp_red`), 메타 줄에 "빨강" 텍스트 보임.
4. 색상 프리셋 관리에서 "빨강" 이름을 "빨강색"으로 변경.
5. 부품 행 메타 줄이 "빨강색"으로 자동 업데이트.

**Step 2: 통과 확인** — `flutter test integration_test/preset_migration_test.dart`

**Step 3: 커밋**

```bash
git add integration_test/preset_migration_test.dart
git commit -m "test(e2e): legacy color migration + reactive name updates"
```

---

### Task 21: 프리셋 CRUD + 행 적용 E2E

**Files:**
- Create: `integration_test/preset_crud_test.dart`

**Step 1:** 시나리오:
1. 새 프로젝트 시작.
2. 부품 섹션 ⚙️ → 프리셋 관리 → 추가 → 라벨 "선반 600", 길이 600, 폭 300, 색 "초록".
3. 닫기.
4. 부품 "프리셋" 버튼 → "선반 600" 선택 → 행 추가 확인 (qty=1, 메타 줄에 "초록").
5. 색상 ⚙️에서 "초록" 색상 삭제 (사용처 경고 dismiss).
6. 부품 행 메타 줄이 "자동"으로 fallback.

**Step 2: 통과 확인**

**Step 3: 커밋**

```bash
git add integration_test/preset_crud_test.dart
git commit -m "test(e2e): preset CRUD + cascade fallback on color delete"
```

---

## 완료 기준

- `flutter analyze` 0 에러.
- `flutter test` + `flutter test integration_test` 모두 PASS.
- 옛 .cutmaster 파일을 열어도 색상이 살아있음 (가까운 시드 매칭 또는 자동 fallback).
- 사용자가 색상/부품/자재 프리셋을 직접 추가/수정/삭제 가능.
- LeftPane 행이 1줄(편집)+메타 줄(이름·결방향·라벨)로 표시.
- 수량 +/- 버튼이 동작.

## 잠재적 함정

- **테스트에서 path_provider 모킹** — `PresetRepository(filePath: ...)`로
  명시 경로 주입 가능하게 설계. 단위 테스트는 tmp dir, integration은
  실제 path_provider 사용.
- **flutter_colorpicker 패키지 호환성** — Flutter 3.10.8 / Dart sdk
  ^3.10.8과 호환되는 버전 확인 (`^1.1.0` 또는 최신 안정).
- **마이그레이션 파일 한 번 저장하면 v2로 변환됨** — 사용자가 옛
  버전으로 롤백 시 호환 안 됨. README/INSTALL 문서에 명시.
- **색상 자동 매핑이 너무 멀면 null** — 이 경우 부품/행은 "자동" 색으로
  떨어짐. 시드 24색 풀이 충분히 다양해서 임계 30(RGB) 안에 대부분 들어옴.
- **컴파일 박살 구간 (Task 6→7→8 사이)** — 같은 PR 안에서 한꺼번에 진행해야
  중간 빌드 깨짐 회피. Task 6의 commit은 Task 7과 묶음.
