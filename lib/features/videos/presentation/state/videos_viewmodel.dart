import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/di/providers.dart';
import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:share_handler/share_handler.dart';
import 'video_presets.dart';
import 'videos_state.dart';

final videosViewModelProvider =
    NotifierProvider<VideosViewModel, VideosState>(VideosViewModel.new);

/// ViewModel of the Videos tab. Probing, compressing and saving live in
/// `CompressVideoUseCase`; this class only holds state and reacts to it.
class VideosViewModel extends Notifier<VideosState> {
  @override
  VideosState build() => const VideosState();

  /// True while a video is being loaded or compressed.
  bool get isBusy => state.isBusy;

  void showResult(String? message) {
    state = state.copyWith(result: message);
  }

  void clearResult() => showResult(null);

  void toggleFab() {
    state = state.copyWith(isFabOpen: !state.isFabOpen);
  }

  void setPresetIndex(int index) {
    state = state.copyWith(presetIndex: index);
  }

  void setMode(VideoMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setResolution(VideoResolution resolution) {
    state = state.copyWith(resolution: resolution);
  }

  void setTargetSizeMb(int mb) {
    state = state.copyWith(targetSizeMb: mb);
  }

  void updateCfrQualitySlider(double value) {
    state = state.copyWith(crfQuality: (value * 100).toInt());
  }

  Future<void> pickVideo() async {
    if (state.isCompressing) return;
    try {
      state = state.copyWith(isLoading: true);

      final path = await ref.read(mediaPickerProvider).pickVideo();

      if (path != null) {
        await _loadVideo(path);
      } else {
        state = state.copyWith(result: "No file picked!", isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
          result: "An error occurred - ${e.toString()}", isLoading: false);
    }
  }

  Future<void> addSharedVideo(List<SharedAttachment>? sharedFiles) async {
    if (sharedFiles != null && sharedFiles.isNotEmpty) {
      await addVideoPath(sharedFiles.elementAt(0).path);
    }
  }

  /// Loads the video at [path] (shared into the app, or dropped onto the
  /// window), replacing the current one.
  Future<void> addVideoPath(String path) async {
    if (state.isCompressing) return;
    try {
      state = state.copyWith(isLoading: true);
      await _loadVideo(path);
    } catch (e) {
      state = state.copyWith(
          result: "An error occurred - ${e.toString()}", isLoading: false);
    }
  }

  Future<void> _loadVideo(String path) async {
    final file = File(path);
    final preview = ref.read(videoPreviewFactoryProvider)(file);

    // The preview is shown only once it reports isInitialized.
    state = state.copyWith(preview: preview);
    await preview.initialize();

    // What the options offer depends on the video, so read its properties now.
    // Failing to read them only means the options cannot be narrowed down.
    VideoData? info;
    try {
      info = await ref.read(videoCompressorProvider).probe(file);
    } catch (_) {
      info = null;
    }
    final bytes = await file.length();

    state = state.copyWith(
      videoFile: file,
      videoInfo: info,
      videoBytes: bytes,
      isLoading: false,
    );
    _fitOptionsToVideo();
  }

  /// Moves a selection that makes no sense for this video (a bigger resolution
  /// or a target above the file's own size) to the nearest one that does.
  void _fitOptionsToVideo() {
    var resolution = state.resolution;
    if (!state.canUseResolution(resolution)) {
      resolution = VideoResolution.original;
    }

    var targetMb = state.targetSizeMb;
    if (!state.canTargetMb(targetMb)) {
      final smaller = kTargetSizeOptionsMb.where(state.canTargetMb);
      if (smaller.isNotEmpty) targetMb = smaller.last;
    }

    state = state.copyWith(resolution: resolution, targetSizeMb: targetMb);
  }

  /// Starts compressing the selected video. Returns once the job has started;
  /// the summary is delivered through [onComplete] when it finishes.
  Future<void> compressVideo({
    required void Function(SummaryReport summaryReport) onComplete,
  }) async {
    try {
      state.currentJob?.cancel();
      state = state.copyWith(currentJob: null);

      final originalFile = state.videoFile;
      if (originalFile == null) return;

      state = state.copyWith(isCompressing: true, percentComplete: 0);

      final job = await ref.read(compressVideoUseCaseProvider)(
        input: originalFile,
        qualityPercent: state.crfQuality,
        preset: kFfmpegPresets[state.presetIndex].value,
        totalDurationMs: state.preview?.duration.inMilliseconds,
        maxShortSide: state.resolution.shortSide,
        targetBytes: state.mode == VideoMode.targetSize
            ? state.targetSizeMb * 1000000
            : null,
        onProgress: (percent) =>
            state = state.copyWith(percentComplete: percent),
        onError: showResult,
      );

      state = state.copyWith(currentJob: job);
      unawaited(_awaitOutcome(job, onComplete));
    } on MediaException catch (e) {
      state = state.copyWith(result: e.message, isCompressing: false);
    } catch (e) {
      state = state.copyWith(
        result: 'Error compressing video: $e',
        isCompressing: false,
        isLoading: false,
      );
    }
  }

  Future<void> _awaitOutcome(
    VideoCompressionJob job,
    void Function(SummaryReport summaryReport) onComplete,
  ) async {
    try {
      final outcome = await job.outcome;

      _forgetJob(job);
      removeVideo();
      await ref.read(workspaceProvider).clear();

      state = state.copyWith(isCompressing: false, isLoading: false);

      onComplete(SummaryReport(
        originalSizeBytes: formatBytes(outcome.originalBytes),
        compressedSizeBytes: formatBytes(outcome.compressedBytes),
        savedBytes: formatBytes(outcome.savedBytes),
        savedPercent: outcome.savedFraction,
        path: outcome.destinationLabel,
        folderPath: outcome.destinationFolder,
      ));
    } on MediaException catch (e) {
      _forgetJob(job);
      state = state.copyWith(
          result: e.message, isCompressing: false, isLoading: false);
    } catch (e) {
      _forgetJob(job);
      state = state.copyWith(
          result: 'Error compressing video: $e',
          isCompressing: false,
          isLoading: false);
    }
  }

  void _forgetJob(VideoCompressionJob job) {
    if (identical(state.currentJob, job)) {
      state = state.copyWith(currentJob: null);
    }
  }

  /// Drops the selected video and resets the compression state.
  void removeVideo() {
    state.preview?.dispose();
    state = state.copyWith(
      preview: null,
      videoFile: null,
      videoInfo: null,
      videoBytes: null,
      isCompressing: false,
      isLoading: false,
      percentComplete: 0,
    );
  }

  void cancelCompressingVideo() {
    final job = state.currentJob;
    if (job != null) {
      unawaited(job.cancel());
      state = state.copyWith(
          currentJob: null, isCompressing: false, isLoading: false);
    } else {
      debugPrint("Tried to cancel but there was no running task");
    }
  }
}
