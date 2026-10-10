import 'dart:io';

import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/features/videos/domain/entities/codec_config.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';

class VideoCompressionOutcome {
  final int originalBytes;
  final int compressedBytes;
  final String destinationLabel;

  const VideoCompressionOutcome({
    required this.originalBytes,
    required this.compressedBytes,
    required this.destinationLabel,
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
  Future<VideoCompressionJob> call({
    required File input,
    required int qualityPercent,
    required String preset,
    required int totalDurationMs,
    required void Function(int percent) onProgress,
    required void Function(String message) onError,
  }) async {
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

    final task = await _compressor.start(
      input: input,
      videoCodec: config.vcodec,
      crf: crf,
      preset: preset,
      totalDurationMs: totalDurationMs,
      onProgress: onProgress,
    );

    return VideoCompressionJob(task, _finish(task, input, onError));
  }

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
    );
  }
}
