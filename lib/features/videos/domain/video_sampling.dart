/// A short stretch of a video, in milliseconds from its start.
class SampleWindow {
  const SampleWindow(this.startMs, this.lengthMs);

  final int startMs;
  final int lengthMs;

  @override
  bool operator ==(Object other) =>
      other is SampleWindow &&
      other.startMs == startMs &&
      other.lengthMs == lengthMs;

  @override
  int get hashCode => Object.hash(startMs, lengthMs);

  @override
  String toString() => 'SampleWindow($startMs, $lengthMs)';
}

/// Videos this short (or shorter) are not sampled: the "sample" is the whole
/// video, so the estimate is exact.
const int kWholeVideoMaxMs = 8000;

/// How many places in a longer video are tried.
const int kSampleCount = 3;

/// How long each try is.
const int kSampleMs = 2000;

/// Where to try a video of [durationMs] to predict how big it will get.
///
/// A few short stretches spread over the video (a sixth, half and five sixths
/// of the way in) catch more of its variety than one long one: most videos
/// have calm and busy parts, and busy parts cost more bytes.
List<SampleWindow> sampleWindows(
  int durationMs, {
  int count = kSampleCount,
  int sampleMs = kSampleMs,
}) {
  if (durationMs <= kWholeVideoMaxMs || count < 1) {
    return [SampleWindow(0, durationMs)];
  }

  return [
    for (var i = 0; i < count; i++)
      SampleWindow(
        ((durationMs * (i + 0.5) / count) - sampleMs / 2)
            .round()
            .clamp(0, durationMs - sampleMs)
            .toInt(),
        sampleMs,
      ),
  ];
}

/// The size of the whole video, from the sizes the [windows] came out at: the
/// bytes per second of the samples, over the whole length. Audio and the file
/// container are in the samples too, so nothing is added.
int extrapolateBytes({
  required List<int> sampleBytes,
  required List<SampleWindow> windows,
  required int durationMs,
}) {
  assert(sampleBytes.length == windows.length);
  final sampledMs = windows.fold<int>(0, (sum, w) => sum + w.lengthMs);
  if (sampledMs <= 0) return 0;
  final bytes = sampleBytes.fold<int>(0, (sum, b) => sum + b);
  return (bytes / sampledMs * durationMs).round();
}
