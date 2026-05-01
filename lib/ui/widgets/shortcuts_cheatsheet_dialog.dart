import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_info_provider.dart';

/// 단축키 치트시트 — 현재 코드베이스에서 사용 중인 단축키를 한 화면에 보여준다.
/// `lib/ui/main_screen.dart`의 `Shortcuts` 정의가 진실의 원천이지만, 사용자에게
/// 보여줄 목적이라면 별도로 들고 있는 편이 충분히 단순하다 (소수의 단축키이고,
/// 각 항목이 사람이 읽기 좋은 한국어 라벨을 가진다).
const List<(String, String)> _shortcuts = [
  ('새 프로젝트', '⌘N'),
  ('파일 열기', '⌘O'),
  ('저장', '⌘S'),
  ('다른 이름으로 저장', '⌘⇧S'),
  ('탭 닫기', '⌘W'),
  ('닫은 탭 다시 열기', '⌘⇧T'),
  ('다음 탭', '⌘Tab'),
  ('이전 탭', '⌘⇧Tab'),
  ('단축키 도움말', '?'),
  ('이름 변경 취소', 'Esc'),
];

class ShortcutsCheatsheetDialog extends ConsumerWidget {
  const ShortcutsCheatsheetDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    return AlertDialog(
      title: const Text('단축키'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, key) in _shortcuts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      key,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _VersionFooter(versionAsync: versionAsync),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter({required this.versionAsync});

  final AsyncValue<String> versionAsync;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color;
    final label = versionAsync.when(
      data: (v) => 'Cutmaster v$v',
      loading: () => 'Cutmaster',
      error: (_, _) => 'Cutmaster',
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color?.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// 어디서든 호출 가능한 헬퍼 — `IconButton.onPressed` 등에서 바로 사용한다.
Future<void> showShortcutsCheatsheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const ShortcutsCheatsheetDialog(),
  );
}
