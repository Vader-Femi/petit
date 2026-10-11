import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_picker.dart';
import 'package:petit/common/domain/services/workspace.dart';
import 'package:petit/features/videos/data/slider_value.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:petit/features/videos/presentation/preview/video_preview.dart';
import 'package:petit/features/videos/presentation/preview/video_preview_factory.dart';
import 'package:petit/service_locator.dart';
import 'package:share_handler/share_handler.dart';

VideosViewModel get getVideosViewModel => Super.init(VideosViewModel());

/// UI state for the video tab. Probing, compressing and saving live in
/// [CompressVideoUseCase]; this class only holds state and reacts to it.
class VideosViewModel {
  final result = RxT<String?>(null);
  final isLoading = RxBool(false);
  final videoFile = RxT<File?>(null);
  final videoPreview = RxT<VideoPreview?>(null);
  final isCompressing = RxBool(false);
  final cfrQualitySlider = RxInt(80);
  final percentageComplete = RxInt(0);
  final selectedPresetIndex = RxInt(1);
  final isFabOpen = RxT<bool>(true);
  final currentTask = RxT<VideoCompressionJob?>(null);

  // Resolved lazily: `getVideosViewModel` constructs a new instance on every
  // access, so nothing may be looked up in the constructor.
  late final MediaPicker _picker = sl<MediaPicker>();
  late final Workspace _workspace = sl<Workspace>();
  late final CompressVideoUseCase _compressVideo = sl<CompressVideoUseCase>();

  /// True while a video is being loaded or compressed.
  bool get isBusy => isLoading.state || isCompressing.state;

  List<SliderValue> ffmpegPresets = [
    // SliderValue(value: "ultrafast", desc: "ultrafast"),
    // SliderValue(value: "superfast", desc: "superfast"),
    // SliderValue(value: "veryfast", desc: "veryfast"),
    // SliderValue(value: "faster", desc: "faster"),
    SliderValue(value: "fast", desc: "Best Quality"),
    SliderValue(value: "medium", desc: "Balanced File"), // 🟢 good default
    SliderValue(value: "slow", desc: "Smallest File"),
    // SliderValue(value: "slower", desc: "slower"),
    // SliderValue(value: "veryslow", desc: "veryslow"),
  ];

  String getLabelForCRFSlider(int value) {
    if (value <= 20) return "Minimal";
    if (value <= 40) return "Very Light";
    if (value <= 60) return "Light";
    if (value <= 80) return "Moderate";
    return "Heavy";
  }

  void setIsLoading(bool isLoading) {
    this.isLoading.state = isLoading;
  }

  void setIsCompressing(bool isCompressing) {
    this.isCompressing.state = isCompressing;
  }

  void setPercentageComplete(int value) {
    percentageComplete.state = value;
  }

  void setPresetIndex(int index) {
    selectedPresetIndex.state = index;
  }

  Future<void> showResult(String? result) async {
    this.result.state = result;
  }

  void updateCfrQualitySlider(double value) {
    cfrQualitySlider.state = (value * 100).toInt();
  }

  Future<void> pickVideo() async {
    if (isCompressing.state) return;
    try {
      setIsLoading(true);

      final path = await _picker.pickVideo();

      if (path != null) {
        final file = File(path);
        final preview = createVideoPreview(file);
        videoPreview.state = preview;
        await preview.initialize();
        videoFile.state = file;

        setIsLoading(false);
      } else {
        await showResult("No file picked!");
        setIsLoading(false);
      }
    } catch (e) {
      await showResult("An error occurred - ${e.toString()}");
      setIsLoading(false);
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
    if (isCompressing.state) return;
    try {
      setIsLoading(true);

      final file = File(path);
      final preview = createVideoPreview(file);
      videoPreview.state = preview;
      await preview.initialize();
      videoFile.state = file;

      setIsLoading(false);
    } catch (e) {
      await showResult("An error occurred - ${e.toString()}");
      setIsLoading(false);
    }
  }

  /// Starts compressing the selected video. Returns immediately; the summary
  /// is delivered through [onComplete] when compression finishes.
  Future<SummaryReport?> compressVideo({
    required Function(SummaryReport summaryReport) onComplete,
  }) async {
    try {
      currentTask.state?.cancel();
      currentTask.state = null;
      if (videoFile.state == null) return null;
      final originalFile = videoFile.state!;
      setIsCompressing(true);
      percentageComplete.state = 0;

      final job = await _compressVideo(
        input: originalFile,
        qualityPercent: cfrQualitySlider.state,
        preset: ffmpegPresets[selectedPresetIndex.state].value,
        totalDurationMs: videoPreview.state?.duration.inMilliseconds,
        onProgress: (percent) => percentageComplete.state = percent,
        onError: showResult,
      );

      currentTask.state = job;
      unawaited(_awaitOutcome(job, onComplete));
    } on MediaException catch (e) {
      await showResult(e.message);
      setIsCompressing(false);
    } catch (e) {
      await showResult('Error compressing video: $e');
      setIsCompressing(false);
      setIsLoading(false);
    }
    return null; // the summary is delivered through onComplete
  }

  Future<void> _awaitOutcome(
    VideoCompressionJob job,
    Function(SummaryReport summaryReport) onComplete,
  ) async {
    try {
      final outcome = await job.outcome;

      if (identical(currentTask.state, job)) currentTask.state = null;
      removeVideo();
      await _workspace.clear();

      setIsCompressing(false);
      setIsLoading(false);

      onComplete(SummaryReport(
        originalSizeBytes: formatBytes(outcome.originalBytes),
        compressedSizeBytes: formatBytes(outcome.compressedBytes),
        savedBytes: formatBytes(outcome.savedBytes),
        savedPercent: outcome.savedFraction,
        path: outcome.destinationLabel,
      ));
    } on MediaException catch (e) {
      if (identical(currentTask.state, job)) currentTask.state = null;
      await showResult(e.message);
      setIsCompressing(false);
      setIsLoading(false);
    } catch (e) {
      if (identical(currentTask.state, job)) currentTask.state = null;
      await showResult('Error compressing video: $e');
      setIsCompressing(false);
      setIsLoading(false);
    }
  }

  String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    final i = (bytes == 0) ? 0 : (bytes.bitLength / 10).floor();
    final size = bytes / (1 << (10 * i));
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  void removeVideo() {
    videoPreview.state?.dispose();
    videoPreview.state = null;
    videoFile.state = null;
    isCompressing.state = false;
    isLoading.state = false;
    percentageComplete.state = 0;
  }

  void cancelCompressingVideo() {
    final task = currentTask.state;
    if (task != null) {
      unawaited(task.cancel());
      currentTask.state = null;
      setIsCompressing(false);
      setIsLoading(false);
    } else {
      debugPrint("⚠️ Tried to cancel but there was no running task");
    }
  }
}
