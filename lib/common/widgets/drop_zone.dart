import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:petit/core/utils/platform_utils.dart';

/// Lets the user drop files anywhere on [child] (desktop only; on other
/// platforms this just returns [child]). While files hover over the window a
/// highlight explains what dropping does.
class DropZone extends StatefulWidget {
  const DropZone({
    super.key,
    required this.onFilesDropped,
    required this.child,
    this.message = 'Drop images or a video to add them',
  });

  final void Function(List<String> paths) onFilesDropped;
  final Widget child;
  final String message;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    if (!PlatformInfo.isDesktop) return widget.child;

    final scheme = Theme.of(context).colorScheme;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        widget.onFilesDropped(details.files.map((file) => file.path).toList());
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_dragging)
            IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  border: Border.all(color: scheme.primary, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
