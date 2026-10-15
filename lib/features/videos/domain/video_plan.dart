import 'dart:io';
import 'dart:math' as math;

import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/features/videos/domain/entities/codec_config.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';

/// Everything the encoder is told for one video: what compressing it and
/// estimating its size both need, so they cannot disagree.
class VideoEncodingPlan {
  const VideoEncodingPlan({
    required this.videoCodec,
    required this.crf,
    this.videoBitrateKbps,
    this.maxShortSide,
    this.hardwareEncoder,
    this.hardwareBitrateKbps,
  });

  /// Software encoder, e.g. `libx264`. Also the one used if hardware fails.
  final String videoCodec;
  final int crf;

  /// Set for a target size; null means "use [crf]".
  final int? videoBitrateKbps;

  /// Null when the video is not larger than the chosen resolution.
  final int? maxShortSide;

  final String? hardwareEncoder;
  final int? hardwareBitrateKbps;
}

/// Works out the [VideoEncodingPlan] for [input] (already probed as [data]).
///
/// Throws a [MediaException] when the video's properties are missing, or a
/// target size is asked for but the video's length is unknown.
///
/// [qualityPercent] is the 0..100 slider; [targetBytes] aims for a size
/// instead; [maxShortSide] scales down (never up); [fastEncoding] asks for
/// the video hardware, used only if this machine has some that works.
Future<VideoEncodingPlan> planVideoEncoding({
  required VideoCompressor compressor,
  required File input,
  required VideoData data,
  required int qualityPercent,
  int? maxShortSide,
  int? targetBytes,
  bool fastEncoding = false,
}) async {
  if (data.frameRate == null ||
      data.pixelHeight == null ||
      data.pixelWidth == null ||
      data.videoCodec == null) {
    throw const MediaException('Error retrieving video properties');
  }

  final config = getVcodecConfigFromCodec(data.videoCodec!);
  final crf = (config.minCrf +
          ((qualityPercent / 100) * (config.maxCrf - config.minCrf)))
      .round();

  int? videoBitrateKbps;
  if (targetBytes != null) {
    final durationMs = data.durationMs;
    if (durationMs == null || durationMs <= 0) {
      throw const MediaException(
          "Could not work out the video's length, so a target size is not possible. Use quality instead.");
    }
    videoBitrateKbps =
        bitrateForTargetSize(targetBytes: targetBytes, durationMs: durationMs);
  }

  final shortSide = math.min(data.pixelWidth!, data.pixelHeight!);
  final scaleTo =
      (maxShortSide != null && shortSide > maxShortSide) ? maxShortSide : null;

  String? hardwareEncoder;
  int? hardwareBitrateKbps;
  if (fastEncoding) {
    hardwareEncoder = await compressor.hardwareEncoderFor(config.vcodec);
    if (hardwareEncoder != null) {
      hardwareBitrateKbps = videoBitrateKbps ??
          fastEncodingBitrateKbps(
            width: data.pixelWidth!,
            height: data.pixelHeight!,
            frameRate: data.frameRate,
            crf: crf,
            hevc: config.vcodec == 'libx265',
            maxShortSide: scaleTo,
            sourceKbps: await _sourceKbps(input, data.durationMs),
          );
    }
  }

  return VideoEncodingPlan(
    videoCodec: config.vcodec,
    crf: crf,
    videoBitrateKbps: videoBitrateKbps,
    maxShortSide: scaleTo,
    hardwareEncoder: hardwareEncoder,
    hardwareBitrateKbps: hardwareBitrateKbps,
  );
}

/// The video's own average bitrate, or null when its length is unknown.
Future<int?> _sourceKbps(File input, int? durationMs) async {
  if (durationMs == null || durationMs <= 0) return null;
  return ((await input.length()) * 8 / durationMs).round();
}
