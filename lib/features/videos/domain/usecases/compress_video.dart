import 'dart:io';

import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/features/videos/domain/entities/codec_config.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/video_plan.dart';

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

class VideoBatchProgress {
  final int completedSteps;
  final int totalSteps;
  final int currentVideoPercent;
  final int overallPercent;

  const VideoBatchProgress({
    required this.completedSteps,
    required this.totalSteps,
    required this.currentVideoPercent,
    required this.overallPercent,
  });
}

/// A compression in progress: cancel it, or await [outcome].
class VideoCompressionJob {
  VideoCompressionJob(this._task, this.outcome, [Future<void> Function()? onCancel])
      : _onCancel = onCancel;

  VideoCompressionJob.fromCancel({
    required this.outcome,
    required Future<void> Function() onCancel,
  })  : _task = null,
        _onCancel = onCancel;

  final VideoCompressionTask? _task;

  /// Completes once the video is compressed and saved. Completes with a
  /// [MediaException] if compression failed or was cancelled.
  final Future<VideoCompressionOutcome> outcome;
  final Future<void> Function()? _onCancel;

  Future<void> cancel() async {
    final onCancel = _onCancel;
    final task = _task;
    if (onCancel != null) {
      await onCancel();
    } else if (task != null) {
      await task.cancel();
    }
  }
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
  ///
  /// With [fastEncoding] the video hardware does the work when this machine
  /// has some that works (see [VideoCompressor.hardwareEncoderFor]); otherwise
  /// it is quietly done the normal way. Hardware needs a bitrate, so without a
  /// [targetBytes] one is worked out from the quality level.
  Future<VideoCompressionJob> call({
    required File input,
    required int qualityPercent,
    required String preset,
    int? totalDurationMs,
    int? maxShortSide,
    int? targetBytes,
    bool fastEncoding = false,
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

    final plan = await planVideoEncoding(
      compressor: _compressor,
      input: input,
      data: data,
      qualityPercent: qualityPercent,
      maxShortSide: maxShortSide,
      targetBytes: targetBytes,
      fastEncoding: fastEncoding,
    );

    final task = await _compressor.start(
      input: input,
      videoCodec: plan.videoCodec,
      crf: plan.crf,
      preset: preset,
      videoBitrateKbps: plan.videoBitrateKbps,
      maxShortSide: plan.maxShortSide,
      hardwareEncoder: plan.hardwareEncoder,
      hardwareBitrateKbps: plan.hardwareBitrateKbps,
      totalDurationMs: _usableDuration(totalDurationMs) ??
          _usableDuration(data.durationMs) ??
          1,
      onProgress: onProgress,
    );

    return VideoCompressionJob(task, _finish(task, input, onError));
  }

  /// Compresses a batch of videos sequentially, reporting overall and per-video
  /// progress. Returns a [VideoCompressionJob] that can be cancelled.
  Future<VideoCompressionJob> compressBatch({
    required List<VideoData> videos,
    required int qualityPercent,
    required String preset,
    int? maxShortSide,
    int? targetBytes,
    bool fastEncoding = false,
    required void Function(VideoBatchProgress progress) onProgress,
    required void Function(String message) onError,
  }) async {
    await _saver.prepare();

    if (videos.isEmpty) {
      return VideoCompressionJob.fromCancel(
        outcome: Future.value(VideoCompressionOutcome(
          originalBytes: 0,
          compressedBytes: 0,
          destinationLabel: _saver.videoDestinationLabel,
          destinationFolder: _saver.destinationFolder,
        )),
        onCancel: () async {},
      );
    }

    var isCancelled = false;
    VideoCompressionTask? activeTask;

    Future<void> cancel() async {
      isCancelled = true;
      final task = activeTask;
      if (task != null) {
        await task.cancel();
      }
    }

    final total = videos.length;
    var totalOriginalBytes = 0;
    var totalCompressedBytes = 0;
    var finished = 0;

    void reportProgress(int currentVideoPercent) {
      final overallPercent = total > 0
          ? (((finished + (currentVideoPercent / 100)) / total) * 100)
              .round()
              .clamp(0, 100)
          : 0;
      onProgress(VideoBatchProgress(
        completedSteps: finished,
        totalSteps: total,
        currentVideoPercent: currentVideoPercent,
        overallPercent: overallPercent,
      ));
    }

    Future<VideoCompressionTask?> startVideo(VideoData video) async {
      final input = video.videoFile;
      VideoData data = video;
      if (data.pixelWidth == null ||
          data.pixelHeight == null ||
          data.videoCodec == null) {
        try {
          data = await _compressor.probe(input);
        } catch (e) {
          onError(
              'Could not probe ${input.path.split(Platform.pathSeparator).last}: $e');
          return null;
        }
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

      return _compressor.start(
        input: input,
        videoCodec: plan.videoCodec,
        crf: plan.crf,
        preset: preset,
        videoBitrateKbps: plan.videoBitrateKbps,
        maxShortSide: plan.maxShortSide,
        hardwareEncoder: plan.hardwareEncoder,
        hardwareBitrateKbps: plan.hardwareBitrateKbps,
        totalDurationMs: _usableDuration(data.durationMs) ?? 1,
        onProgress: (percent) {
          reportProgress(percent);
        },
      );
    }

    // Start video 0 before returning so the task is live immediately
    final firstVideo = videos[0];
    final firstInput = firstVideo.videoFile;
    final firstOriginalSize = await firstInput.length();
    totalOriginalBytes += firstOriginalSize;

    final firstTask = await startVideo(firstVideo);
    activeTask = firstTask;

    final outcomeFuture = () async {
      // Process video 0 result
      if (firstTask != null) {
        try {
          final compressed = await firstTask.result;
          var sizeAfter = await compressed.length();
          final File finalFile;
          if (sizeAfter >= firstOriginalSize) {
            finalFile = firstInput;
            sizeAfter = firstOriginalSize;
          } else {
            finalFile = compressed;
          }
          totalCompressedBytes += sizeAfter;
          try {
            await _saver.saveVideo(finalFile.path);
          } catch (e) {
            onError('Error saving video: $e');
          }

          if (finalFile == compressed) {
            try {
              if (await compressed.exists()) {
                await compressed.delete();
              }
            } catch (_) {}
          }
        } on MediaException catch (e) {
          if (total == 1 || isCancelled) rethrow;
          onError(
              '${firstInput.path.split(Platform.pathSeparator).last}: ${e.message}');
          totalCompressedBytes += firstOriginalSize;
        } catch (e) {
          if (total == 1 || isCancelled) rethrow;
          onError(
              'Error compressing ${firstInput.path.split(Platform.pathSeparator).last}: $e');
          totalCompressedBytes += firstOriginalSize;
        } finally {
          activeTask = null;
          finished++;
          if (total > 1) reportProgress(0);
        }
      } else {
        totalCompressedBytes += firstOriginalSize;
        finished++;
        if (total > 1) reportProgress(0);
      }

      // Process subsequent videos (1 .. total - 1)
      for (var i = 1; i < total; i++) {
        if (isCancelled) throw const MediaException('Cancelled');

        final video = videos[i];
        final input = video.videoFile;
        final originalSize = await input.length();
        totalOriginalBytes += originalSize;

        try {
          final task = await startVideo(video);
          if (task == null) {
            totalCompressedBytes += originalSize;
            finished++;
            reportProgress(0);
            continue;
          }
          activeTask = task;
          final compressed = await task.result;

          var sizeAfter = await compressed.length();
          final File finalFile;
          if (sizeAfter >= originalSize) {
            finalFile = input;
            sizeAfter = originalSize;
          } else {
            finalFile = compressed;
          }
          totalCompressedBytes += sizeAfter;
          try {
            await _saver.saveVideo(finalFile.path);
          } catch (e) {
            onError('Error saving video: $e');
          }

          if (finalFile == compressed) {
            try {
              if (await compressed.exists()) {
                await compressed.delete();
              }
            } catch (_) {}
          }
        } on MediaException catch (e) {
          if (isCancelled) rethrow;
          onError(
              '${input.path.split(Platform.pathSeparator).last}: ${e.message}');
          totalCompressedBytes += originalSize;
        } catch (e) {
          if (isCancelled) rethrow;
          onError(
              'Error compressing ${input.path.split(Platform.pathSeparator).last}: $e');
          totalCompressedBytes += originalSize;
        } finally {
          activeTask = null;
          finished++;
          reportProgress(0);
        }
      }

      if (isCancelled) throw const MediaException('Cancelled');

      return VideoCompressionOutcome(
        originalBytes: totalOriginalBytes,
        compressedBytes: totalCompressedBytes,
        destinationLabel: _saver.videoDestinationLabel,
        destinationFolder: _saver.destinationFolder,
      );
    }();

    return VideoCompressionJob.fromCancel(
      outcome: outcomeFuture,
      onCancel: cancel,
    );
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

/// Tells whether Fast encoding (video hardware) can be used for a video of a
/// given codec on this machine.
class CheckFastEncodingUseCase {
  CheckFastEncodingUseCase(this._compressor);

  final VideoCompressor _compressor;

  /// [codec] is the video's codec name as probed (`h264`, `hevc`, ...).
  Future<bool> call(String codec) async {
    try {
      final config = getVcodecConfigFromCodec(codec);
      return await _compressor.hardwareEncoderFor(config.vcodec) != null;
    } catch (_) {
      return false;
    }
  }
}
