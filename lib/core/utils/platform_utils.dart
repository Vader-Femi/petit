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

  /// `macos`, `ios`, `android`, `windows`, `linux` (or `other`), as used to pick
  /// hardware video encoders.
  static String get osName {
    if (isMacOS) return 'macos';
    if (isIOS) return 'ios';
    if (isAndroid) return 'android';
    if (isWindows) return 'windows';
    if (isLinux) return 'linux';
    return 'other';
  }

  /// How many images to compress at the same time. Desktop computers have the
  /// cores and the memory for a few (each one is decoded in full), while phones
  /// already use several cores inside the native encoder and have little spare
  /// memory, so they do one at a time.
  static int get imageConcurrency =>
      isDesktop ? (Platform.numberOfProcessors ~/ 2).clamp(1, 4).toInt() : 1;

  /// Firebase Crashlytics has no Windows or Linux implementation.
  static bool get supportsCrashlytics => !(isWindows || isLinux);

  /// Firebase Analytics is skipped on Windows and Linux (Firebase is not
  /// initialised on Linux and there is no verified Windows implementation).
  static bool get supportsAnalytics => !(isWindows || isLinux);
}
