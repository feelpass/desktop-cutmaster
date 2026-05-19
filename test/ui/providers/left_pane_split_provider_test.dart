import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cutmaster/data/local/workspace_db.dart';
import 'package:cutmaster/ui/providers/left_pane_split_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('loadInitial returns default when not set', () async {
    final db = await WorkspaceDb.openInMemory();
    expect(await LeftPaneSplitNotifier.loadInitial(db),
        kLeftPaneTopHeightDefault);
    await db.close();
  });

  test('setHeight persists and clamps; loadInitial reads back', () async {
    final db = await WorkspaceDb.openInMemory();
    final n = LeftPaneSplitNotifier(db, kLeftPaneTopHeightDefault);

    await n.setHeight(320);
    expect(n.state, 320);
    expect(await LeftPaneSplitNotifier.loadInitial(db), 320);

    await n.setHeight(50); // below min
    expect(n.state, kLeftPaneTopHeightMin);
    expect(await LeftPaneSplitNotifier.loadInitial(db), kLeftPaneTopHeightMin);

    await n.setHeight(9999); // above max
    expect(n.state, kLeftPaneTopHeightMax);

    await db.close();
  });

  test('loadInitial recovers from invalid stored value', () async {
    final db = await WorkspaceDb.openInMemory();
    await db.setSetting('left_pane_top_height', 'not-a-number');
    expect(await LeftPaneSplitNotifier.loadInitial(db),
        kLeftPaneTopHeightDefault);
    await db.close();
  });
}
