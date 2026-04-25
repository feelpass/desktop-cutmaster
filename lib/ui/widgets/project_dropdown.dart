import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/project.dart';
import '../../l10n/app_localizations.dart';
import '../providers/current_project_provider.dart';
import '../providers/db_provider.dart';
import '../theme/app_colors.dart';
import 'rename_project_dialog.dart';

class ProjectDropdown extends ConsumerWidget {
  const ProjectDropdown({super.key, required this.currentName});

  final String currentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            final db = await ref.read(dbProvider.future);
            final list = await db.listProjects();
            if (!context.mounted) return;
            showMenu<_MenuAction>(
              context: context,
              position: const RelativeRect.fromLTRB(160, 48, 160, 0),
              items: [
                ...list.map((p) => PopupMenuItem(
                      value: _MenuAction.select(p),
                      child: Text(p.name),
                    )),
                if (list.isNotEmpty) const PopupMenuDivider(),
                PopupMenuItem(
                  value: _MenuAction.rename,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 16),
                      const SizedBox(width: 4),
                      const Text('이름 변경'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _MenuAction.create,
                  child: Row(
                    children: [
                      const Icon(Icons.add, size: 16),
                      const SizedBox(width: 4),
                      Text(t.newProject),
                    ],
                  ),
                ),
              ],
            ).then((action) async {
              if (action == null) return;
              if (action.kind == _Kind.create) {
                ref.read(currentProjectProvider.notifier).setProject(
                      Project.create(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        name: t.newProject,
                      ),
                    );
              } else if (action.kind == _Kind.select &&
                  action.project != null) {
                ref
                    .read(currentProjectProvider.notifier)
                    .setProject(action.project!);
              } else if (action.kind == _Kind.rename) {
                if (!context.mounted) return;
                final newName = await showRenameProjectDialog(
                  context,
                  currentName: currentName,
                );
                if (newName != null) {
                  ref
                      .read(currentProjectProvider.notifier)
                      .updateName(newName);
                }
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentName,
                  style: const TextStyle(
                    color: AppColors.textOnHeader,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down,
                    color: AppColors.textOnHeader, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Kind { create, select, rename }

class _MenuAction {
  final _Kind kind;
  final Project? project;
  const _MenuAction._(this.kind, this.project);
  static const create = _MenuAction._(_Kind.create, null);
  static const rename = _MenuAction._(_Kind.rename, null);
  static _MenuAction select(Project p) => _MenuAction._(_Kind.select, p);
}
