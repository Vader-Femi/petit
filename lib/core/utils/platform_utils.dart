import 'dart:io';

import 'package:flutter/foundation.dart';

/// Central place for platform checks, so the rest of the app never touches
/// `dart:io`'s `Platform` directly (which throws on web).
class PlatformInfo {
  PlatformInfo._();

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  /// Firebase Crashlytics has no Windows or Linux implementation.
  static bool get supportsCrashlytics => !(isWindows || isLinux);
}
