import 'dart:math' as math;

/// Audio is re-encoded at about this rate (FFmpeg's default for AAC).
const int kAssumedAudioKbps = 128;

/// Never aim below this video bitrate; the picture would fall apart.
const int kMinVideoKbps = 100;

/// The video bitrate (in kbit/s) that should give a file of about
/// [targetBytes] for a clip lasting [durationMs].
///
/// 5% of the target is left for the container's own overhead. In tests with
/// x264 and x265 this landed 8 to 12 percent under the target, so the result
/// is a safe "about", not an exact size.
int bitrateForTargetSize({
  required int targetBytes,
  required int durationMs,
  int audioKbps = kAssumedAudioKbps,
}) {
  final totalKbps = targetBytes * 8 * 0.95 / (durationMs / 1000) / 1000;
  return math.max(kMinVideoKbps, (totalKbps - audioKbps).round());
}
