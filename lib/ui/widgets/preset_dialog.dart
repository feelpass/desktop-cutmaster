import 'package:flutter/material.dart';

import '../../domain/models/stock_sheet.dart';
import '../../l10n/app_localizations.dart';

/// 한국 합판 표준 규격 프리셋. 친구 가구공장 워크플로우에 맞춰 추가/조정.
const _presets = <_Preset>[
  _Preset('2440 × 1220 (12T)', 2440, 1220, '12T 합판'),
  _Preset('1220 × 2440 (12T)', 1220, 2440, '12T 합판'),
  _Preset('2440 × 1220 (15T)', 2440, 1220, '15T 합판'),
  _Preset('2440 × 1220 (18T)', 2440, 1220, '18T 합판'),
  _Preset('2440 × 1220 (MDF 9T)', 2440, 1220, 'MDF 9T'),
  _Preset('2440 × 1220 (MDF 18T)', 2440, 1220, 'MDF 18T'),
];

Future<StockSheet?> showPresetDialog(BuildContext context) {
  final t = AppLocalizations.of(context);
  return showDialog<StockSheet>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(t.preset),
      children: _presets.map((p) {
        return SimpleDialogOption(
          onPressed: () {
            Navigator.pop(
              ctx,
              StockSheet(
                id: 's${DateTime.now().microsecondsSinceEpoch}',
                length: p.length,
                width: p.width,
                qty: 1,
                label: p.label,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(p.title),
          ),
        );
      }).toList(),
    ),
  );
}

class _Preset {
  final String title;
  final double length;
  final double width;
  final String label;
  const _Preset(this.title, this.length, this.width, this.label);
}
