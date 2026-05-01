# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Cutmaster — Flutter desktop app (macOS / Windows) for plywood cut-list optimization. UI/text is Korean (`Locale('ko')`); user-facing strings live in `lib/l10n/app_ko.arb`.

## Design system

UI 작업(위젯·테마·색·간격·타이포)의 단일 소스 오브 트루스는 @DESIGN.md 이다 (Linear-inspired design system). 새 위젯을 만들거나 스타일을 수정할 때는 거기 정의된 토큰·반경 스케일·weight 위계를 따른다. 한글 본문 폰트는 Pretendard로 유지하되 weight/letter-spacing/line-height 규칙은 그대로 적용한다.

## Common commands

```bash
flutter pub get
flutter analyze                       # lints (flutter_lints, see analysis_options.yaml)
flutter test                          # full unit + widget suite
flutter test test/domain/solver/ffd_solver_test.dart   # single file
flutter test --plain-name "FFDSolver places small parts"  # single test by name
flutter run -d macos                  # dev run
flutter run -d windows                # dev run on Windows host
flutter test integration_test/        # integration tests (require a desktop device)
```

Release builds go through `scripts/`, which runs `pub get → analyze → test → build → package`:

```bash
./scripts/build-macos.sh [vX.Y.Z|--no-dmg]    # → release/cutmaster-<ver>-macos.dmg
./scripts/build-windows.sh [vX.Y.Z]           # macOS → triggers GH Actions, downloads zip
./scripts/build-windows.ps1                   # on Windows host directly
```

Pushing a tag `v*` triggers `.github/workflows/build-windows.yml` (windows-latest runner) which uploads `cutmaster-windows.zip` to the GitHub Release. There is no macOS CI — release DMGs are built locally.

## Architecture (big picture)

### Layered structure under `lib/`

- `domain/models/` — pure data: `Project`, `CutPart`, `StockSheet`, `CuttingPlan`, `SolverMode`. All persisted via `toJson` / `fromJson`. `Project.schemaVersion` is the on-disk JSON version (currently 4) — bumping requires a migration test in `test/domain/models/`.
- `domain/solver/` — algorithms. Three implementations behind `SolverMode`:
  - `FFDSolver` — 2D guillotine + First Fit Decreasing, tries 4 sort × 2 score variants and picks best.
  - `StripCutSolver` — panel-saw-compatible strip cuts (full-width passes only).
  - `AutoRecommend` — runs both strip directions and returns the winner with `runnerUp` populated.
  - All solvers run **inside `compute()`** via `solver_isolate.dart` to keep the UI thread free; `solver_provider.runCalculate` is the single entry point from UI.
- `data/file/project_file.dart` — `.cutmaster` JSON IO with **atomic write** (tmp file + rename) and **mtime-conflict detection** (`ConflictException` when an external editor like Dropbox/iCloud touched the file mid-edit; the conflict is auto-forked and surfaced as `ConflictNotice`).
- `data/local/workspace_db.dart` — sqflite_ffi DB at `<appSupport>/workspace.db` storing the workspace meta (open tabs, recent files, recently-closed). Project content is **not** stored here.
- `data/local/project_db.dart` — legacy DB; only read at startup by `data/migration/legacy_to_files.dart` to one-shot-export old `cutmaster.db` projects into `~/Documents/Cutmaster/*.cutmaster`.
- `data/preset/` — global color/material presets (`PresetRepository`). `ColorMatcher` resolves a v1 ARGB int → preset id during legacy load (see "Color preset resolution" below).
- `data/csv/parts_csv_importer.dart` — CSV import (`PART, W, D, T, MATERIAL, GRAIN, QTY, ARTICLE, ...`). Auto-creates color presets for unseen `MATERIAL` values and feeds `ARTICLE` into `Project.name` when blank.
- `ui/main_screen.dart` + `ui/widgets/` — Material 3 layout: tab bar, left input pane (stocks/parts/options/order info/cut conditions), result pane (`CuttingCanvas` + summary). Right-pane has been collapsed into the result pane.
- `ui/providers/` — Riverpod state:
  - `tabsProvider` (`TabsNotifier`) — open tabs, dirty tracking, autosave, session restore.
  - `activeProjectProvider` — convenience selector for the active tab's `Project`.
  - `solver_provider.dart` — `cuttingPlanProvider`, `isCalculatingProvider`, `displayedPlanProvider` (winner vs runner-up), and the `runCalculate(ref)` action.
  - `presetsProvider` — global color presets.

### App boot (`lib/main.dart`)

`main()` does ordered work that downstream code depends on:
1. `sqfliteFfiInit()` (required on desktop).
2. Create `~/Documents/Cutmaster/` and `<appSupport>/autosave/`.
3. Load `PresetsNotifier` **before** anything that opens project files — `colorMatcher` is a closure over `presetsNotifier.state.colors` so legacy ARGB→preset resolution always sees the latest list (matters when the user edits presets before opening a v1 file).
4. Open `WorkspaceDb`, then run **legacy migration** only if `cutmaster.db` exists AND workspace has zero recent files (so re-running it on an already-migrated machine is a no-op).
5. Build `TabsNotifier` and call `restoreSession()`; if no tabs, open one untitled.
6. `runApp` with overrides: `tabsProvider`, `presetsProvider` are pre-built so they aren't re-instantiated.

`didRequestAppExit` flushes pending autosaves + saves session before allowing exit — don't rely on dispose for persistence.

### Solver dispatch & material grouping

`runCalculate` is **not** "one solver call per project". It:
1. Calls `Project.derivedStocks()` — auto-derives a 2440×1220 (qty=999) `StockSheet` per unique `(colorPresetId, thickness)` combination found in `parts`. User-entered `project.stocks` is intentionally ignored.
2. Groups parts by the same `(colorPresetId, thickness)` key.
3. Runs the solver **once per material group** and applies headcuts (`headcutTop/Bottom/Left/Right`) by shrinking the effective stock area, then offsets placed-part coordinates back to the original (2440×1220) frame so the canvas can render the headcut shadow.
4. Merges all sheets into one `CuttingPlan` with combined efficiency.

When adding solver knobs, plumb them through `solver_isolate.solveInIsolate` → `_SolverInput` (isolate boundary requires immutable types).

### Persistence rules (don't break)

- Project content lives **per file** in `~/Documents/Cutmaster/<name>.cutmaster`. Multi-tab autosave (500 ms debounce) writes through `ProjectFileService.write` (atomic).
- Untitled tabs autosave to `<appSupport>/autosave/` until explicitly saved.
- The workspace DB only references files by path. Renaming a saved tab also renames the file on disk.
- Bumping `Project.schemaVersion` requires: (a) `Project.fromJson` reads new fields with defaults, (b) `Project.toJson` writes them, (c) a migration test in `test/domain/models/project_*_migration_test.dart`.

## Conventions

- Strings: lints follow `flutter_lints` defaults; no project-specific overrides.
- Korean is the default UI locale; do not hardcode user-facing English. Add new strings to `lib/l10n/app_ko.arb` and run `flutter gen-l10n` (driven by `l10n.yaml`) to regenerate `app_localizations*.dart`.
- Comments in `lib/` are predominantly Korean; match the surrounding style.
- The font asset `assets/fonts/Pretendard-Regular.ttf` is required — keep it referenced in `pubspec.yaml`.
