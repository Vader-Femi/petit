import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

/// Flutter's default scroll behaviour ignores mouse drags on desktop, so the
/// image carousel could not be dragged. Allow every pointer type.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
