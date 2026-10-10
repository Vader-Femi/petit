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

  /// Starts compressing [input]. [onProgress] receives 0..100.
  Future<VideoCompressionTask> start({
    required File input,
    required String videoCodec,
    required int crf,
    required String preset,
    required int totalDurationMs,
    required void Function(int percent) onProgress,
  });
}
