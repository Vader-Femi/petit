import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/di/providers.dart';
import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:petit/common/domain/progress_eta.dart';
import 'package:petit/features/settings/domain/entities/app_settings.dart';
import 'package:petit/features/settings/presentation/state/settings_viewmodel.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';
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
  VideosState build() {
    // Changing the defaults in Settings applies at once while no video is
    // picked; a video being prepared keeps the settings it was started with.
    ref.listen(settingsViewModelProvider, (_, settings) {
      if (state.videoFile == null && !state.isBusy) {
        state = _withDefaults(state, settings);
      }
    });

    return _withDefaults(
        const VideosState(), ref.read(settingsViewModelProvider));
  }

  VideosState _withDefaults(VideosState base, AppSettings settings) {
    return base.copyWith(
      mode: settings.videoUseTargetSize
          ? VideoMode.targetSize
          : VideoMode.quality,
      crfQuality: settings.videoQuality,
      resolution: settings.videoResolution,
      presetIndex: settings.videoPresetIndex,
      targetSizeMb: settings.videoTargetSizeMb,
      fastEncoding: settings.videoFastEncoding,
    );
  }

  /// True while a video is being loaded or compressed.
  bool get isBusy => state.isBusy;

  void showResult(String? message) {
    state = state.copyWith(result: message);
  }

  void clearResult() => showResult(null);

  void toggleFab() {
    state = state.copyWith(isFabOpen: !state.isFabOpen);
  }

  /// Pauses playback, e.g. when the user moves to another tab: the page stays
  /// alive there, so the video would otherwise keep playing out of sight.
  void pausePlayback() {
    final preview = state.preview;
    if (preview == null || !preview.isPlaying) return;
    unawaited(preview.togglePlayback());
    // The play/pause button reads the preview directly; a new state makes the
    // page rebuild it.
    state = state.copyWith();
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
    state = state.copyWith(targetSizeMb: mb.clamp(1, kMaxTargetSizeMb).toInt());
  }

  void updateCfrQualitySlider(double value) {
    state = state.copyWith(crfQuality: (value * 100).toInt());
  }

  Future<void> pickVideo() async {
    if (state.isCompressing) return;
    try {
      state = state.copyWith(isLoading: true);

      final paths = await ref.read(mediaPickerProvider).pickVideos();

      if (paths.isNotEmpty) {
        await addVideoPaths(paths);
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
      await addVideoPaths(sharedFiles.map((f) => f.path).toList());
    }
  }

  /// Loads the video at [path] (shared into the app, or dropped onto the
  /// window), replacing the current selection.
  Future<void> addVideoPath(String path) async {
    await addVideoPaths([path]);
  }

  /// Replaces the current selection with the videos at [paths].
  Future<void> addVideoPaths(List<String> paths) async {
    if (paths.isEmpty || state.isCompressing) return;
    try {
      state = state.copyWith(isLoading: true);
      cancelEstimate();
      state.preview?.dispose();

      final videos = await ref.read(readVideosUseCaseProvider)(paths);
      if (videos.isEmpty) {
        state = state.copyWith(result: "No file picked!", isLoading: false);
        return;
      }

      final preview =
          ref.read(videoPreviewFactoryProvider)(videos.first.videoFile);
      state = state.copyWith(preview: preview);
      await preview.initialize();

      state = state.copyWith(
        pickedVideos: videos,
        currentVideoIndex: 0,
        isLoading: false,
        fastEncodingAvailable: false,
        preview: preview,
      );

      _fitOptionsToVideo();
      unawaited(_checkFastEncodingForBatch(videos));
    } catch (e) {
      state.preview?.dispose();
      state = state.copyWith(
        pickedVideos: const [],
        preview: null,
        videoFile: null,
        videoInfo: null,
        videoBytes: null,
        result: "An error occurred - ${e.toString()}",
        isLoading: false,
      );
    }
  }

  /// Changes the currently viewed video in the carousel.
  Future<void> updateCurrentVideoIndex(int index) async {
    if (state.pickedVideos.isEmpty) return;
    final clamped = index.clamp(0, state.pickedVideos.length - 1);
    if (clamped == state.currentVideoIndex && state.preview != null) return;

    await _activatePreviewForIndex(clamped);
  }

  Future<void> nextVideo() async {
    if (state.currentVideoIndex < state.pickedVideos.length - 1) {
      await updateCurrentVideoIndex(state.currentVideoIndex + 1);
    }
  }

  Future<void> previousVideo() async {
    if (state.currentVideoIndex > 0) {
      await updateCurrentVideoIndex(state.currentVideoIndex - 1);
    }
  }

  Future<void> _activatePreviewForIndex(int index) async {
    cancelEstimate();
    final previousPreview = state.preview;
    state = state.copyWith(preview: null, currentVideoIndex: index);
    previousPreview?.dispose();

    final activeVideo = state.currentVideo;
    if (activeVideo == null) return;

    final preview =
        ref.read(videoPreviewFactoryProvider)(activeVideo.videoFile);
    state = state.copyWith(preview: preview);
    try {
      await preview.initialize();
      if (state.currentVideoIndex == index) {
        state = state.copyWith(preview: preview);
      } else {
        preview.dispose();
      }
    } catch (e) {
      state = state.copyWith(
        preview: null,
        result: "An error occurred - ${e.toString()}",
      );
    }
  }

  Future<void> _checkFastEncodingForBatch(List<VideoData> videos) async {
    var anyAvailable = false;
    for (final v in videos) {
      if (!ref.mounted) return;
      final codec = v.videoCodec;
      if (codec != null) {
        final available =
            await ref.read(checkFastEncodingUseCaseProvider)(codec);
        if (available) {
          anyAvailable = true;
          break;
        }
      }
    }
    if (!ref.mounted) return;
    // The user may have picked other videos, or none, in the meantime.
    if (state.pickedVideos.isEmpty) return;
    if (state.pickedVideos.first.videoFile.path !=
        videos.first.videoFile.path) {
      return;
    }
    state = state.copyWith(fastEncodingAvailable: anyAvailable);
  }

  /// Works out how big the video would get with the current choices, by
  /// compressing a few short samples of it. Takes seconds, so the user asks for
  /// it (and can cancel); the answer holds until a choice changes.
  /// Bumped when an estimate is started or cancelled, so a late answer from
  /// an older one is ignored.
  int _estimateGeneration = 0;

  Future<void> estimateSize() async {
    final file = state.videoFile;
    if (file == null || state.isBusy || state.isEstimating) return;

    // The estimate writes into the same work folder as every other job.
    if (ref.read(imagesViewModelProvider).isBusy) {
      showResult('Wait for the images to finish first');
      return;
    }
    final blocking = state.warnings.where((w) => w.blocksStart);
    if (blocking.isNotEmpty) {
      showResult(blocking.first.message);
      return;
    }

    final key = state.settingsKey;
    final run = ++_estimateGeneration;
    state = state.copyWith(
      isEstimating: true,
      estimatePercent: 0,
      estimate: null,
      estimateKey: null,
    );

    try {
      final job = await ref.read(estimateVideoSizeUseCaseProvider)(
        input: file,
        qualityPercent: state.crfQuality,
        preset: kFfmpegPresets[state.presetIndex].value,
        maxShortSide: state.resolution.shortSide,
        fastEncoding: state.usesFastEncoding,
        targetBytes: state.mode == VideoMode.targetSize
            ? state.targetSizeMb * 1000000
            : null,
        onProgress: (percent) {
          if (run == _estimateGeneration) {
            state = state.copyWith(estimatePercent: percent);
          }
        },
      );
      state = state.copyWith(estimateJob: job);

      final result = await job.result;

      // Cancelled, or the video was removed, while it ran.
      if (run != _estimateGeneration) return;
      state = state.copyWith(
        estimate: result,
        estimateKey: key,
        estimateJob: null,
        isEstimating: false,
      );
    } on MediaException catch (e) {
      // A cancelled or replaced estimate is not an error.
      if (run != _estimateGeneration) return;
      state = state.copyWith(estimateJob: null, isEstimating: false);
      showResult(e.message);
    } catch (e) {
      if (run != _estimateGeneration) return;
      state = state.copyWith(estimateJob: null, isEstimating: false);
      showResult('Could not estimate the size: $e');
    }
  }

  /// Stops an estimate in progress.
  void cancelEstimate() {
    final job = state.estimateJob;
    if (!state.isEstimating) return;
    _estimateGeneration++;
    state = state.copyWith(isEstimating: false, estimateJob: null);
    if (job != null) unawaited(job.cancel());
  }

  /// Fast encoding on or off for this video.
  void setFastEncoding(bool enabled) {
    state = state.copyWith(fastEncoding: enabled);
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
      if (smaller.isNotEmpty) {
        targetMb = smaller.last;
      } else if (state.videoBytes != null) {
        // A video smaller than the smallest preset: half its size, at least 1.
        final half = (state.videoBytes! / 2000000).floor();
        targetMb = half < 1 ? 1 : half;
      }
    }

    state = state.copyWith(resolution: resolution, targetSizeMb: targetMb);
  }

  /// Starts compressing the selected video(s). Returns once the job has started;
  /// the summary is delivered through [onComplete] when it finishes.
  Future<void> compressVideo({
    required void Function(SummaryReport summaryReport) onComplete,
  }) async {
    try {
      state.currentJob?.cancel();
      state = state.copyWith(currentJob: null);

      final videos = state.pickedVideos.isNotEmpty
          ? state.pickedVideos
          : (state.videoFile != null
              ? [
                  VideoData(
                    videoFile: state.videoFile!,
                    pixelWidth: state.videoInfo?.pixelWidth,
                    pixelHeight: state.videoInfo?.pixelHeight,
                    videoCodec: state.videoInfo?.videoCodec,
                    frameRate: state.videoInfo?.frameRate,
                    durationMs: state.videoInfo?.durationMs ??
                        state.preview?.duration.inMilliseconds,
                    fileBytes: state.videoBytes,
                  )
                ]
              : <VideoData>[]);

      if (videos.isEmpty) return;

      // Both tabs share one work folder, which a finishing job empties.
      if (ref.read(imagesViewModelProvider).isBusy) {
        showResult('Wait for the images to finish first');
        return;
      }

      // A running estimate would compete with the real job.
      cancelEstimate();

      // Settings that cannot help are explained in the panel; do not start.
      final blocking = state.warnings.where((w) => w.blocksStart);
      if (blocking.isNotEmpty) {
        showResult(blocking.first.message);
        return;
      }

      final eta = ProgressEta()..start();
      state = state.copyWith(
        isCompressing: true,
        percentComplete: 0,
        completedVideos: 0,
        totalVideos: videos.length,
        currentVideoPercent: 0,
        eta: null,
      );

      final isBatch = videos.length > 1;
      final keepAliveTitle =
          isBatch ? 'Compressing videos' : 'Compressing video';
      await ref.read(jobKeepAliveProvider).begin(title: keepAliveTitle);

      final job = await ref.read(compressVideoUseCaseProvider).compressBatch(
        videos: videos,
        qualityPercent: state.crfQuality,
        preset: kFfmpegPresets[state.presetIndex].value,
        maxShortSide: state.resolution.shortSide,
        fastEncoding: state.usesFastEncoding,
        targetBytes: state.mode == VideoMode.targetSize
            ? state.targetSizeMb * 1000000
            : null,
        onProgress: (batchProgress) {
          eta.update(batchProgress.overallPercent / 100);
          state = state.copyWith(
            percentComplete: batchProgress.overallPercent,
            completedVideos: batchProgress.completedSteps,
            totalVideos: batchProgress.totalSteps,
            currentVideoPercent: batchProgress.currentVideoPercent,
            eta: eta.remaining,
          );

          final text = isBatch
              ? 'Video ${batchProgress.completedSteps + 1} of ${batchProgress.totalSteps} (${batchProgress.currentVideoPercent}%)'
              : '${batchProgress.overallPercent}% done';

          ref.read(jobKeepAliveProvider).progress(
                percent: batchProgress.overallPercent,
                text: text,
              );
        },
        onError: showResult,
      );

      state = state.copyWith(currentJob: job);
      unawaited(_awaitOutcome(job, onComplete));
    } on MediaException catch (e) {
      unawaited(ref.read(jobKeepAliveProvider).end());
      state = state.copyWith(result: e.message, isCompressing: false);
    } catch (e) {
      unawaited(ref.read(jobKeepAliveProvider).end());
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
      if (ref.mounted) {
        await ref.read(jobKeepAliveProvider).end();
      }

      _forgetJob(job);
      removeVideo();
      if (ref.mounted) {
        await ref.read(workspaceProvider).clear();
        state = state.copyWith(isCompressing: false, isLoading: false);
      }

      onComplete(SummaryReport(
        originalSizeBytes: formatBytes(outcome.originalBytes),
        compressedSizeBytes: formatBytes(outcome.compressedBytes),
        savedBytes: formatBytes(outcome.savedBytes),
        savedPercent: outcome.savedFraction,
        path: outcome.destinationLabel,
        folderPath: outcome.destinationFolder,
      ));
    } on MediaException catch (e) {
      if (ref.mounted) {
        unawaited(ref.read(jobKeepAliveProvider).end());
        _forgetJob(job);
        state = state.copyWith(
            result: e.message, isCompressing: false, isLoading: false);
      }
    } catch (e) {
      if (ref.mounted) {
        unawaited(ref.read(jobKeepAliveProvider).end());
        _forgetJob(job);
        state = state.copyWith(
            result: 'Error compressing video: $e',
            isCompressing: false,
            isLoading: false);
      }
    }
  }

  void _forgetJob(VideoCompressionJob job) {
    if (identical(state.currentJob, job)) {
      state = state.copyWith(currentJob: null);
    }
  }

  /// Drops the selected video(s) and resets the compression state.
  void removeVideo() {
    cancelEstimate();
    state.preview?.dispose();
    state = state.copyWith(
      pickedVideos: const [],
      currentVideoIndex: 0,
      preview: null,
      videoFile: null,
      videoInfo: null,
      videoBytes: null,
      isCompressing: false,
      isLoading: false,
      percentComplete: 0,
      completedVideos: 0,
      totalVideos: 0,
      currentVideoPercent: 0,
      eta: null,
      fastEncodingAvailable: false,
      estimate: null,
      estimateKey: null,
      isEstimating: false,
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
