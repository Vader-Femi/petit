import 'dart:io';

import 'package:petit/features/videos/domain/entities/video_data.dart';

/// A running compression.
abstract interface class VideoCompressionTask {
  /// Completes with the compressed file. Completes with a [MediaException]
  /// if compression failed or was cancelled.
  Future<File> get result;

  Future<void> cancel();
}

abstract interface class VideoCompressor {
  /// Reads the video's properties. Throws a [MediaException] on failure.
  Future<VideoData> probe(File video);

  /// The name of a hardware encoder (e.g. `h264_videotoolbox`) that works on
  /// this machine for the software codec [videoCodec] (`libx264`, `libx265`),
  /// or null when there is none. Slow the first time (it tries them), instant
  /// after.
  Future<String?> hardwareEncoderFor(String videoCodec);

  /// Starts compressing [input]. [onProgress] receives 0..100.
  ///
  /// With [videoBitrateKbps] the encoder aims for that bitrate (a target file
  /// size) and [crf] is ignored. With [maxShortSide] the video is scaled so its
  /// shorter side has that many pixels; callers pass it only when it is smaller
  /// than the video, because the video is never enlarged.
  ///
  /// With a [hardwareEncoder] (from [hardwareEncoderFor]) the work goes to the
  /// video hardware at [hardwareBitrateKbps]. If that fails part way, the
  /// compression is run again with the normal settings above, so asking for
  /// hardware can only make things faster, never break them.
  Future<VideoCompressionTask> start({
    required File input,
    required String videoCodec,
    required int crf,
    required String preset,
    required int totalDurationMs,
    required void Function(int percent) onProgress,
    int? videoBitrateKbps,
    int? maxShortSide,
    String? hardwareEncoder,
    int? hardwareBitrateKbps,
  });
}
