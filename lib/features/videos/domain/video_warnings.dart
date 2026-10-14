import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';

/// A compression level (0..100) at or below this is "Minimal": the encoder
/// aims for near-original quality, which is not always a smaller file.
const int kMinimalCompressionPercent = 20;

/// A video that already averages less than this (video and audio together) has
/// little left to squeeze out.
const int kAlreadySmallKbps = 1000;

/// Something about the chosen settings the user should know before starting.
class VideoSettingsWarning {
  const VideoSettingsWarning(this.message, {this.blocksStart = false});

  final String message;

  /// True when starting would be pointless, so the app refuses to start.
  final bool blocksStart;
}

/// Warnings about settings that are unlikely to make the video smaller.
///
/// There is no way to know the result before encoding, so the quality-based
/// ones are hints ("may"), and the target-size ones are exact. The app also
/// keeps the original whenever the result is not smaller.
///
/// [downscales] is true when the chosen resolution really makes the picture
/// smaller, which shrinks the file whatever else is set.
List<VideoSettingsWarning> videoSettingsWarnings({
  required bool aimsForSize,
  required int qualityPercent,
  required int targetMb,
  required bool downscales,
  int? videoBytes,
  int? durationMs,
}) {
  final warnings = <VideoSettingsWarning>[];
  final seconds = (durationMs != null && durationMs > 0) ? durationMs / 1000 : null;

  if (aimsForSize) {
    final targetBytes = targetMb * 1000000;

    if (videoBytes != null && targetBytes >= videoBytes) {
      warnings.add(VideoSettingsWarning(
        'The target ($targetMb MB) is not smaller than this video '
        '(${formatBytes(videoBytes)}), so compressing cannot help. '
        'Choose a smaller size.',
        blocksStart: true,
      ));
    } else if (seconds != null) {
      final floor = minimumTargetBytes(durationMs: durationMs!);
      if (targetBytes < floor) {
        warnings.add(VideoSettingsWarning(
          'A video this long cannot get below about ${formatBytes(floor)}. '
          'The result will be that size, at the lowest picture quality.',
        ));
      }
    }
    return warnings;
  }

  if (downscales) return warnings;

  if (qualityPercent <= kMinimalCompressionPercent) {
    warnings.add(const VideoSettingsWarning(
      'Minimal compression may not make this video smaller. If the result '
      'is not smaller, the original is kept.',
    ));
  } else if (videoBytes != null && seconds != null) {
    final kbps = videoBytes * 8 / seconds / 1000;
    if (kbps < kAlreadySmallKbps) {
      warnings.add(VideoSettingsWarning(
        'This video is already small (about ${kbps.round()} kbit/s), so '
        'compressing it again may not shrink it. If the result is not '
        'smaller, the original is kept.',
      ));
    }
  }

  return warnings;
}
