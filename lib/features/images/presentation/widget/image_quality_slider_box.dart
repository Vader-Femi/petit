import 'package:flutter/material.dart';

import '../../../../common/widgets/custom_tool_tip.dart';

class ImageQualitySliderBox extends StatelessWidget {
  final double sliderValue; // between 0.0 and 1.0
  final bool isGlobal;
  final bool showGlobalSwitch;
  final void Function(double) onSliderChanged;
  final void Function(bool)? onGlobalToggle;

  const ImageQualitySliderBox({
    super.key,
    required this.sliderValue,
    required this.isGlobal,
    required this.onSliderChanged,
    this.onGlobalToggle,
    this.showGlobalSwitch = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "Image Quality",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CustomTapTooltip(
                    message: "• Adjust image quality.\n"
                        "• Lower values reduce size\n"
                        "but may affect clarity.\n"
                        "• 20% - 98% Recommended",
                    child: Icon(Icons.info_outline, size: 18),
                  ),
                  // Tooltip(
                  //   message:
                  //       "Adjust image quality. Lower values reduce size but may affect clarity.",
                  //   waitDuration: Duration(milliseconds: 50),
                  //   showDuration: Duration(seconds: 5),
                  //   child: Icon(Icons.info_outline, size: 18),
                  // ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "${(sliderValue * 100).round()}%",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Slider(
                          value: sliderValue.clamp(0.0, 1.0),
                          onChanged: onSliderChanged,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 🔁 Global Toggle Switch
          if (showGlobalSwitch)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Use same quality for all images",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: isGlobal,
                  onChanged: onGlobalToggle,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
