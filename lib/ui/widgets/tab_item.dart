import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class TabItem extends StatefulWidget {
  const TabItem({
    super.key,
    required this.displayName,
    required this.isActive,
    required this.isDirty,
    required this.isUntitled,
    required this.onTap,
    required this.onClose,
    required this.onRenameSubmit,
  });

  final String displayName;
  final bool isActive;
  final bool isDirty;
  final bool isUntitled;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ValueChanged<String> onRenameSubmit;

  @override
  State<TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<TabItem> {
  static final _forbiddenRegex = RegExp(r'[\\/:*?"<>|]');

  bool _editing = false;
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focus = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _ctrl.text = widget.displayName;
      _ctrl.selection =
          TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  void _commit() {
    final raw = _ctrl.text.trim();
    if (raw.isNotEmpty) widget.onRenameSubmit(raw);
    setState(() => _editing = false);
  }

  void _cancel() {
    setState(() => _editing = false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive ? Colors.white : Colors.white24;
    final fg = widget.isActive ? Colors.black87 : AppColors.textOnHeader;
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
        child: Row(
          children: [
            if ((widget.isUntitled || widget.isDirty) && !_editing)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  key: const ValueKey('tab-dirty-dot'),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: fg.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Expanded(
              child: _editing
                  ? Focus(
                      onKeyEvent: _onKey,
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        style: TextStyle(color: fg, fontSize: 13),
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(_forbiddenRegex),
                        ],
                        onSubmitted: (_) => _commit(),
                        onTapOutside: (_) => _commit(),
                      ),
                    )
                  : GestureDetector(
                      key: const ValueKey('tab-name'),
                      onDoubleTap: _startEdit,
                      child: Text(
                        widget.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontSize: 13),
                      ),
                    ),
            ),
            if (!_editing) ...[
              const SizedBox(width: 4),
              InkWell(
                key: const ValueKey('tab-close'),
                onTap: widget.onClose,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 14, color: fg),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
