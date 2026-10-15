import 'dart:async';
import 'dart:io';

import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/video_plan.dart';
import 'package:petit/features/videos/domain/video_sampling.dart';

/// What compressing a video with the chosen settings is expected to produce.
class VideoSizeEstimate {
  const VideoSizeEstimate({
    required this.originalBytes,
    required this.estimatedBytes,
    required this.sampledMs,
    required this.sampleCount,
    required this.totalMs,
  });

  final int originalBytes;
  final int estimatedBytes;

  /// How much of the video was really compressed to work this out.
  final int sampledMs;
  final int sampleCount;
  final int totalMs;

  /// The whole video was compressed, so the size is exact (not extrapolated).
  bool get isExact => sampledMs >= totalMs;

  /// Compressing is not expected to make the video smaller; the original
  /// would be kept.
  bool get isLarger => estimatedBytes >= originalBytes;

  /// Fraction (0..1) of the original size expected to be saved.
  double get savedFraction => originalBytes <= 0 || isLarger
      ? 0.0
      : ((originalBytes - estimatedBytes) / originalBytes)
          .clamp(0.0, 1.0)
          .toDouble();
}

/// An estimate in progress: cancel it, or await [result].
class VideoEstimateJob {
  VideoEstimateJob(this.result, this._cancel);

  /// Completes with the estimate, or with a [MediaException] if it failed or
  /// was cancelled.
  final Future<VideoSizeEstimate> result;
  final Future<void> Function() _cancel;

  Future<void> cancel() => _cancel();
}

/// Predicts how big a video will be by really compressing a few short
/// stretches of it with the chosen settings, and scaling up their size. Much
/// more telling than a rule of thumb, because it sees this video's own mix of
/// calm and busy scenes, and uses the same encoder (hardware or not) as the
/// real job. Short videos are compressed whole, so the answer is exact.
class EstimateVideoSizeUseCase {
  EstimateVideoSizeUseCase(this._compressor);

  final VideoCompressor _compressor;

  /// Takes the same choices as `CompressVideoUseCase`. [onProgress] receives
  /// 0..100 across all the stretches.
  Future<VideoEstimateJob> call({
    required File input,
    required int qualityPercent,
    required String preset,
    int? maxShortSide,
    int? targetBytes,
    bool fastEncoding = false,
    void Function(int percent)? onProgress,
  }) async {
    final VideoData data;
    try {
      data = await _compressor.probe(input);
    } on MediaException {
      throw const MediaException('Error retrieving video properties');
    }

    final durationMs = data.durationMs;
    if (durationMs == null || durationMs <= 0) {
      throw const MediaException(
          "Could not work out the video's length, so its size cannot be estimated.");
    }

    final plan = await planVideoEncoding(
      compressor: _compressor,
      input: input,
      data: data,
      qualityPercent: qualityPercent,
      maxShortSide: maxShortSide,
      targetBytes: targetBytes,
      fastEncoding: fastEncoding,
    );

    final windows = sampleWindows(durationMs);
    final run = _Run();

    Future<VideoSizeEstimate> work() async {
      final sizes = <int>[];

      for (var i = 0; i < windows.length; i++) {
        if (run.cancelled) {
          throw const MediaException('Estimate cancelled.');
        }
        final window = windows[i];

        final task = await _compressor.start(
          input: input,
          videoCodec: plan.videoCodec,
          crf: plan.crf,
          preset: preset,
          videoBitrateKbps: plan.videoBitrateKbps,
          maxShortSide: plan.maxShortSide,
          hardwareEncoder: plan.hardwareEncoder,
          hardwareBitrateKbps: plan.hardwareBitrateKbps,
          startMs: window.startMs,
          limitMs: window.lengthMs,
          totalDurationMs: window.lengthMs,
          onProgress: (percent) =>
              onProgress?.call(((i + percent / 100) / windows.length * 100).round()),
        );
        run.current = task;

        final File sample;
        try {
          sample = await task.result;
        } on MediaException {
          if (run.cancelled) throw const MediaException('Estimate cancelled.');
          rethrow;
        }

        sizes.add(await sample.length());
        try {
          await sample.delete();
        } on FileSystemException {
          // Left in the work folder, which is emptied after the next job.
        }
      }

      onProgress?.call(100);
      return VideoSizeEstimate(
        originalBytes: await input.length(),
        estimatedBytes: extrapolateBytes(
          sampleBytes: sizes,
          windows: windows,
          durationMs: durationMs,
        ),
        sampledMs: windows.fold<int>(0, (sum, w) => sum + w.lengthMs),
        sampleCount: windows.length,
        totalMs: durationMs,
      );
    }

    return VideoEstimateJob(work(), run.cancel);
  }
}

class _Run {
  bool cancelled = false;
  VideoCompressionTask? current;

  Future<void> cancel() async {
    cancelled = true;
    await current?.cancel();
  }
}
