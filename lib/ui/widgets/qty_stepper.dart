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
