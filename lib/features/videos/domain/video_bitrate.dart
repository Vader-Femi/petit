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

/// Bits per pixel a hardware H.264 encoder needs for roughly the quality of
/// software x264 at CRF 23. Hardware encoders are less efficient, so this is
/// above what x264 itself needs (about 0.07).
const double kFastBitsPerPixel = 0.1;

/// HEVC needs about this share of H.264's bitrate for the same quality.
const double kHevcBitrateShare = 0.65;

/// The bitrate (kbit/s) to give a hardware encoder so the result looks about
/// as good as software encoding at the quality level [crf].
///
/// Hardware encoders cannot do constant quality (CRF), only a bitrate, so the
/// level is turned into one: every 6 CRF steps halve it, as with x264.
/// [crf] is the software CRF (x265's scale runs about 5 higher than x264's for
/// the same quality, which is why [hevc] shifts it). The result is capped below
/// the source's own bitrate ([sourceKbps]), because compressing must not ask
/// for more than the file already has.
///
/// An estimate, not a promise: it is meant to make Fast encoding land in the
/// right area, not to hit a size.
int fastEncodingBitrateKbps({
  required int width,
  required int height,
  int? frameRate,
  required int crf,
  required bool hevc,
  int? maxShortSide,
  int? sourceKbps,
}) {
  final fps = (frameRate ?? 30).clamp(1, 120);

  var scale = 1.0;
  final shortSide = math.min(width, height);
  if (maxShortSide != null && shortSide > maxShortSide) {
    scale = maxShortSide / shortSide;
  }
  final pixelsPerSecond = width * height * scale * scale * fps;

  final h264Crf = hevc ? crf - 5 : crf;
  var bitsPerPixel = kFastBitsPerPixel * math.pow(2, (23 - h264Crf) / 6);
  if (hevc) bitsPerPixel *= kHevcBitrateShare;

  final wanted = pixelsPerSecond * bitsPerPixel / 1000;

  final ceiling = math.max(
    kMinVideoKbps,
    sourceKbps == null ? kMaxFastKbps : (sourceKbps * 0.9).floor(),
  );
  return wanted.round().clamp(kMinVideoKbps, math.min(ceiling, kMaxFastKbps)).toInt();
}

/// Upper limit for [fastEncodingBitrateKbps], in kbit/s.
const int kMaxFastKbps = 100000;
