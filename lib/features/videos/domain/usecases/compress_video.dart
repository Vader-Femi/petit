import 'dart:io';
import 'dart:math' as math;

import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/features/videos/domain/entities/codec_config.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';

class VideoCompressionOutcome {
  final int originalBytes;
  final int compressedBytes;
  final String destinationLabel;

  /// Folder the user can open, or null (see [MediaSaver.destinationFolder]).
  final String? destinationFolder;

  const VideoCompressionOutcome({
    required this.originalBytes,
    required this.compressedBytes,
    required this.destinationLabel,
    this.destinationFolder,
  });

  int get savedBytes => originalBytes - compressedBytes;

  /// Fraction (0..1) of the original size that was saved.
  double get savedFraction => originalBytes <= 0
      ? 0.0
      : (savedBytes / originalBytes).clamp(0, 1).toDouble();
}

/// A compression in progress: cancel it, or await [outcome].
class VideoCompressionJob {
  VideoCompressionJob(this._task, this.outcome);

  final VideoCompressionTask _task;

  /// Completes once the video is compressed and saved. Completes with a
  /// [MediaException] if compression failed or was cancelled.
  final Future<VideoCompressionOutcome> outcome;

  Future<void> cancel() => _task.cancel();
}

class CompressVideoUseCase {
  CompressVideoUseCase(this._compressor, this._saver);

  final VideoCompressor _compressor;
  final MediaSaver _saver;

  /// Probes [input], picks encoder settings from its codec, and starts
  /// compressing. [qualityPercent] is the 0..100 slider value.
  ///
  /// [targetBytes] aims for a file of about that size instead of a quality
  /// level (needs the video's length). [maxShortSide] scales the video down so
  /// its shorter side has that many pixels; it is ignored when the video is
  /// not larger than that, because videos are never enlarged.
  /// [totalDurationMs] is used for progress; when missing, the probed
  /// duration is used instead.
  Future<VideoCompressionJob> call({
    required File input,
    required int qualityPercent,
    required String preset,
    int? totalDurationMs,
    int? maxShortSide,
    int? targetBytes,
    required void Function(int percent) onProgress,
    required void Function(String message) onError,
  }) async {
    // May ask the user where to save; throws MediaException if they decline.
    await _saver.prepare();

    final VideoData data;
    try {
      data = await _compressor.probe(input);
    } on MediaException {
      throw const MediaException('Error retrieving video properties');
    }

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

    final task = await _compressor.start(
      input: input,
      videoCodec: config.vcodec,
      crf: crf,
      preset: preset,
      videoBitrateKbps: videoBitrateKbps,
      maxShortSide: scaleTo,
      totalDurationMs: _usableDuration(totalDurationMs) ??
          _usableDuration(data.durationMs) ??
          1,
      onProgress: onProgress,
    );

    return VideoCompressionJob(task, _finish(task, input, onError));
  }

  /// Durations of zero (or unknown) would make progress meaningless.
  int? _usableDuration(int? ms) => (ms != null && ms > 0) ? ms : null;

  Future<VideoCompressionOutcome> _finish(
    VideoCompressionTask task,
    File input,
    void Function(String message) onError,
  ) async {
    final compressed = await task.result;

    final sizeBefore = await input.length();
    var sizeAfter = await compressed.length();

    // Keep the original if compressing did not make it smaller.
    final File finalFile;
    if (sizeAfter >= sizeBefore) {
      finalFile = input;
      sizeAfter = sizeBefore;
    } else {
      finalFile = compressed;
    }

    try {
      await _saver.saveVideo(finalFile.path);
    } catch (e) {
      onError("Error occurred - $e");
    }

    return VideoCompressionOutcome(
      originalBytes: sizeBefore,
      compressedBytes: sizeAfter,
      destinationLabel: _saver.videoDestinationLabel,
      destinationFolder: _saver.destinationFolder,
    );
  }
}
