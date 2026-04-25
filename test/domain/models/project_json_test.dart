import 'package:flutter_test/flutter_test.dart';
import 'package:cutmaster/domain/models/project.dart';
import 'package:cutmaster/domain/models/stock_sheet.dart';
import 'package:cutmaster/domain/models/cut_part.dart';

void main() {
  test('Project.toJson / fromJson roundtrip preserves all fields', () {
    final orig = Project.create(id: 'p1', name: '책장').copyWith(
      stocks: [
        const StockSheet(
          id: 's1', length: 2440, width: 1220, qty: 2,
          label: '12T', grainDirection: GrainDirection.lengthwise,
          colorPresetId: 'cp_walnut',
        ),
      ],
      parts: [
        const CutPart(
          id: 'pa1', length: 600, width: 400, qty: 4,
          label: '문짝', grainDirection: GrainDirection.widthwise,
        ),
      ],
      kerf: 5,
      grainLocked: true,
      showPartLabels: false,
      useSingleSheet: true,
    );

    final json = orig.toJson();
    expect(json['schemaVersion'], 2);

    final back = Project.fromJson(json);
    expect(back.id, orig.id);
    expect(back.name, orig.name);
    expect(back.stocks, orig.stocks);
    expect(back.parts, orig.parts);
    expect(back.kerf, orig.kerf);
    expect(back.grainLocked, orig.grainLocked);
    expect(back.showPartLabels, orig.showPartLabels);
    expect(back.useSingleSheet, orig.useSingleSheet);
    expect(back.createdAt, orig.createdAt);
  });

  test('fromJson rejects unknown future schemaVersion', () {
    expect(
      () => Project.fromJson({'schemaVersion': 999, 'id': 'x', 'name': 'y'}),
      throwsA(isA<FormatException>()),
    );
  });
}
