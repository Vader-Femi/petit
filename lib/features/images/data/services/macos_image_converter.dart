import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Converts an image to JPEG with macOS's own image decoders (ImageIO), which
/// read HEIC/HEIF. FFmpeg and Flutter cannot. The native side is the
/// `ImageConverter` in `macos/Runner/MainFlutterWindow.swift`.
class MacosImageConverter {
  MacosImageConverter({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'petit/image_converter';

  final MethodChannel _channel;

  /// Writes [input] as a JPEG to [output]. Returns true on success, false if
  /// the conversion failed or there is no native side (not running on macOS).
  Future<bool> convertToJpeg(
    String input,
    String output, {
    double quality = 0.95,
  }) async {
    try {
      await _channel.invokeMethod<String>('convertToJpeg', {
        'input': input,
        'output': output,
        'quality': quality,
      });
      return true;
    } on PlatformException catch (e) {
      debugPrint('macOS image conversion failed: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
