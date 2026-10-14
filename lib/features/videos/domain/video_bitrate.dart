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

/// Largest target size accepted, in megabytes (1 MB = 1,000,000 bytes).
const int kMaxTargetSizeMb = 9999;

/// The smallest file [bitrateForTargetSize] can aim for with a clip lasting
/// [durationMs]: below this the video bitrate stops at [kMinVideoKbps], so
/// the result is bigger than the target.
///
/// That is `(kMinVideoKbps + audioKbps)` kbit/s for the whole clip, plus the
/// 5% that [bitrateForTargetSize] holds back for the container.
int minimumTargetBytes({
  required int durationMs,
  int audioKbps = kAssumedAudioKbps,
}) {
  final seconds = durationMs / 1000;
  return ((kMinVideoKbps + audioKbps) * 1000 / 8 * seconds / 0.95).round();
}
