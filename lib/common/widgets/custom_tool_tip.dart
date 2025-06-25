import 'package:flutter/material.dart';

class CustomTapTooltip extends StatefulWidget {
  final String message;
  final Widget child;

  const CustomTapTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  @override
  State<CustomTapTooltip> createState() => _CustomTapTooltipState();
}

class _CustomTapTooltipState extends State<CustomTapTooltip> {
  OverlayEntry? _overlayEntry;

  void _showTooltip() {
    final renderBox = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = overlay.semanticBounds.size;

    const tooltipWidth = 220.0;
    const tooltipHeight = 40.0;
    const padding = 8.0;

    double dx = offset.dx + size.width / 2 - tooltipWidth / 2;
    double dy = offset.dy - tooltipHeight - padding;

    // Clamp to screen
    if (dx < padding) dx = padding;
    if (dx + tooltipWidth > screenSize.width) dx = screenSize.width - tooltipWidth - padding;
    if (dy < padding) dy = offset.dy + size.height + padding; // show below if no space above

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: dx,
        top: dy,
        width: tooltipWidth,
        child: Material(
          color: Colors.transparent,
          child: AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.message,
                style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    Future.delayed(const Duration(seconds: 4), () {
      _hideTooltip();
    });
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showTooltip,
      child: widget.child,
    );
  }
}


