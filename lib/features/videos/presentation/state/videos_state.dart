import 'dart:io';

import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:petit/features/videos/presentation/preview/video_preview.dart';

const Object _unset = Object();

/// How the amount of compression is chosen.
enum VideoMode {
  /// A quality level (the "Compression Level" slider).
  quality,

  /// A file size to aim for.
  targetSize,
}

/// Target sizes offered, in megabytes (1 MB = 1,000,000 bytes).
const List<int> kTargetSizeOptionsMb = [5, 10, 25, 50, 100];

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
    this.mode = VideoMode.quality,
    this.resolution = VideoResolution.original,
    this.targetSizeMb = 25,
    this.videoInfo,
    this.videoBytes,
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

  final VideoMode mode;
  final VideoResolution resolution;

  /// Size to aim for in [VideoMode.targetSize], in megabytes.
  final int targetSizeMb;

  /// Properties of the selected video (null if they could not be read).
  final VideoData? videoInfo;

  /// Size of the selected video file.
  final int? videoBytes;

  /// The shorter side of the selected video in pixels, if known.
  int? get sourceShortSide {
    final width = videoInfo?.pixelWidth;
    final height = videoInfo?.pixelHeight;
    if (width == null || height == null) return null;
    return width < height ? width : height;
  }

  /// Whether [resolution] would make the video smaller. Original always can.
  bool canUseResolution(VideoResolution resolution) {
    final side = resolution.shortSide;
    final source = sourceShortSide;
    return side == null || source == null || side < source;
  }

  /// Whether a target of [mb] megabytes is smaller than the video itself.
  bool canTargetMb(int mb) {
    final bytes = videoBytes;
    return bytes == null || mb * 1000000 < bytes;
  }

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
    VideoMode? mode,
    VideoResolution? resolution,
    int? targetSizeMb,
    Object? videoInfo = _unset,
    Object? videoBytes = _unset,
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
      mode: mode ?? this.mode,
      resolution: resolution ?? this.resolution,
      targetSizeMb: targetSizeMb ?? this.targetSizeMb,
      videoInfo:
          identical(videoInfo, _unset) ? this.videoInfo : videoInfo as VideoData?,
      videoBytes:
          identical(videoBytes, _unset) ? this.videoBytes : videoBytes as int?,
    );
  }
}
