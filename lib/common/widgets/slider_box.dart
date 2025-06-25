import 'package:flutter/material.dart';

import 'custom_tool_tip.dart';

Widget buildSliderBox({
  required BuildContext context,
  required String label,
  required String minValue,
  required String maxValue,
  required String tootTipMessage,
  required Widget slider,
  bool showGlobalSwitch = false,
  bool isGlobal = false,
  ValueChanged<bool>? onGlobalToggle,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            // Tooltip(
            //   message: tootTipMessage,
            //   waitDuration: Duration(milliseconds: 50),
            //   showDuration: Duration(seconds: 5),
            //   child: Icon(Icons.info_outline, size: 18),
            // ),

            CustomTapTooltip(
              message: tootTipMessage,
              child: Icon(Icons.info_outline, size: 18),
            ),
            Expanded(child: slider),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(minValue),
            Text(maxValue),
          ],
        ),
        SizedBox(height: 10),
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
