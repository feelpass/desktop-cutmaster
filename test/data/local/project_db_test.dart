import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:cutmaster/data/local/project_db.dart';
import 'package:cutmaster/domain/models/project.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Project save → load roundtrip preserves all fields', () async {
    final db = await ProjectDb.openInMemory();
    final orig = Project.create(id: 'p1', name: '테스트').copyWith(
      stocks: [
        const StockSheet(
          id: 's1',
          length: 2440,
          width: 1220,
          qty: 1,
          label: '12T',
          grainDirection: GrainDirection.lengthwise,
        ),
      ],
      parts: [
        const CutPart(
          id: 'pa1',
          length: 600,
          width: 400,
          qty: 4,
          label: '문짝',
          grainDirection: GrainDirection.lengthwise,
        ),
      ],
      kerf: 5,
      grainLocked: true,
      showPartLabels: false,
      useSingleSheet: true,
    );

    await db.upsertProject(orig);
    final loaded = await db.loadProject('p1');

    expect(loaded, isNotNull);
    expect(loaded!.name, '테스트');
    expect(loaded.stocks.length, 1);
    expect(loaded.stocks.first, orig.stocks.first);
    expect(loaded.parts.length, 1);
    expect(loaded.parts.first, orig.parts.first);
    expect(loaded.kerf, 5);
    expect(loaded.grainLocked, true);
    expect(loaded.showPartLabels, false);
    expect(loaded.useSingleSheet, true);

    await db.close();
  });

  test('listProjects returns all projects ordered by updatedAt desc', () async {
    final db = await ProjectDb.openInMemory();
    final p1 = Project.create(id: 'a', name: '첫째');
    await Future.delayed(const Duration(milliseconds: 5));
    final p2 = Project.create(id: 'b', name: '둘째');
    await db.upsertProject(p1);
    await db.upsertProject(p2);

    final list = await db.listProjects();
    expect(list.length, 2);
    expect(list.first.id, 'b'); // 더 최근

    await db.close();
  });
}
