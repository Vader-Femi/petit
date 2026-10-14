import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';

/// A box for typing a target size in whole megabytes, next to the preset
/// chips. It stays empty while one of [presets] is chosen and shows the number
/// when a custom size is in use. Only valid sizes (1 to [kMaxTargetSizeMb])
/// are reported through [onChanged].
class TargetSizeField extends StatefulWidget {
  const TargetSizeField({
    super.key,
    required this.valueMb,
    required this.presets,
    required this.onChanged,
  });

  final int valueMb;
  final List<int> presets;
  final ValueChanged<int> onChanged;

  @override
  State<TargetSizeField> createState() => _TargetSizeFieldState();
}

class _TargetSizeFieldState extends State<TargetSizeField> {
  late final TextEditingController _controller =
      TextEditingController(text: _textFor(widget.valueMb));

  String _textFor(int mb) => widget.presets.contains(mb) ? '' : '$mb';

  @override
  void didUpdateWidget(TargetSizeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The size changed from outside (a chip, or another video was picked).
    // Typing also changes it, but then the box already shows that number, and
    // an empty box that is being retyped must not be refilled.
    if (widget.valueMb != oldWidget.valueMb &&
        int.tryParse(_controller.text) != widget.valueMb) {
      _controller.text = _textFor(widget.valueMb);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _error {
    final text = _controller.text;
    if (text.isEmpty) return null;
    final mb = int.tryParse(text);
    if (mb == null || mb < 1) return 'Enter at least 1 MB';
    return null;
  }

  void _onChanged(String text) {
    final mb = int.tryParse(text);
    if (mb != null && mb >= 1 && mb <= kMaxTargetSizeMb) widget.onChanged(mb);
    setState(() {}); // refresh the error text
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: kMaxTargetSizeMb.toString().length,
        onChanged: _onChanged,
        decoration: InputDecoration(
          labelText: 'Custom size',
          suffixText: 'MB',
          counterText: '',
          isDense: true,
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
