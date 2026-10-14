import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/features/images/data/services/heif_arguments.dart';
import 'package:petit/features/images/data/services/macos_image_converter.dart';

/// Turns HEIC/HEIF photos (what iPhones save) into JPEG on desktop, where
/// Flutter and the `image` package cannot read them.
///
/// macOS asks the system (ImageIO). Everywhere, and as a fallback on macOS,
/// the bundled FFmpeg is used: FFmpeg 7.1 and newer reads HEIC itself, and the
/// FFmpeg Kit version this app uses bundles 8.1.2 on every platform, so no
/// extra native library (such as libheif) is needed.
class DesktopHeifConverter {
  DesktopHeifConverter({MacosImageConverter? macosConverter})
      : _macosConverter = macosConverter ?? MacosImageConverter();

  final MacosImageConverter _macosConverter;

  /// Writes a JPEG of [source] to [outPath]. With [maxLongSide] the picture
  /// is made smaller (the macOS converter always keeps full size). Returns
  /// false if the file could not be read.
  Future<bool> toJpeg(
    String source,
    String outPath, {
    int? maxLongSide,
  }) async {
    if (PlatformInfo.isMacOS &&
        await _macosConverter.convertToJpeg(source, outPath)) {
      return true;
    }

    try {
      final session = await FFmpegKit.executeWithArguments(
        buildHeifToJpegArguments(
          inputPath: source,
          outputPath: outPath,
          maxLongSide: maxLongSide,
        ),
      );
      final code = await session.getReturnCode();
      return ReturnCode.isSuccess(code) && await File(outPath).exists();
    } catch (e) {
      debugPrint('HEIC conversion failed: $e');
      return false;
    }
  }
}
