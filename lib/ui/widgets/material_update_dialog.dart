import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 자재 라이브러리 수정 시 영향 받는 프로젝트에 띄우는 다이얼로그.
/// design doc [A1] 정책: 스냅샷 고정, 수정 시 명시적 업데이트 확인.
Future<bool?> showMaterialUpdateDialog(BuildContext context) {
  final t = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.materialUpdatedTitle),
      content: Text(t.materialUpdatedBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t.no),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(t.yes),
        ),
      ],
    ),
  );
}
