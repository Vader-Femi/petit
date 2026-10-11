import 'dart:io';

import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:petit/features/videos/presentation/preview/video_preview.dart';

const Object _unset = Object();

/// Everything the Videos tab shows. Immutable: change it with [copyWith].
class VideosState {
  const VideosState({
    this.result,
    this.isLoading = false,
    this.videoFile,
    this.preview,
    this.isCompressing = false,
    this.crfQuality = 80,
    this.percentComplete = 0,
    this.presetIndex = 1,
    this.isFabOpen = true,
    this.currentJob,
  });

  /// One-shot message for a snackbar; the page clears it once shown.
  final String? result;
  final bool isLoading;
  final File? videoFile;
  final VideoPreview? preview;
  final bool isCompressing;

  /// "Compression Level" slider, 0..100.
  final int crfQuality;
  final int percentComplete;

  /// Index into the FFmpeg presets ("Desired File Size" slider).
  final int presetIndex;
  final bool isFabOpen;

  /// The running compression, if any.
  final VideoCompressionJob? currentJob;

  /// True while a video is being loaded or compressed.
  bool get isBusy => isLoading || isCompressing;

  /// Nullable fields can be set to null by passing null explicitly.
  VideosState copyWith({
    Object? result = _unset,
    bool? isLoading,
    Object? videoFile = _unset,
    Object? preview = _unset,
    bool? isCompressing,
    int? crfQuality,
    int? percentComplete,
    int? presetIndex,
    bool? isFabOpen,
    Object? currentJob = _unset,
  }) {
    return VideosState(
      result: identical(result, _unset) ? this.result : result as String?,
      isLoading: isLoading ?? this.isLoading,
      videoFile:
          identical(videoFile, _unset) ? this.videoFile : videoFile as File?,
      preview:
          identical(preview, _unset) ? this.preview : preview as VideoPreview?,
      isCompressing: isCompressing ?? this.isCompressing,
      crfQuality: crfQuality ?? this.crfQuality,
      percentComplete: percentComplete ?? this.percentComplete,
      presetIndex: presetIndex ?? this.presetIndex,
      isFabOpen: isFabOpen ?? this.isFabOpen,
      currentJob: identical(currentJob, _unset)
          ? this.currentJob
          : currentJob as VideoCompressionJob?,
    );
  }
}
