import 'dart:io';

import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:petit/features/videos/domain/usecases/estimate_video_size.dart';
import 'package:petit/features/videos/domain/video_warnings.dart';
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
    this.pickedVideos = const [],
    this.currentVideoIndex = 0,
    File? videoFile,
    this.preview,
    this.isCompressing = false,
    this.crfQuality = 80,
    this.percentComplete = 0,
    this.completedVideos = 0,
    this.totalVideos = 0,
    this.currentVideoPercent = 0,
    this.eta,
    this.fastEncoding = false,
    this.fastEncodingAvailable = false,
    this.estimate,
    this.estimateKey,
    this.estimateJob,
    this.isEstimating = false,
    this.estimatePercent = 0,
    this.presetIndex = 1,
    this.isFabOpen = true,
    this.currentJob,
    this.mode = VideoMode.quality,
    this.resolution = VideoResolution.original,
    this.targetSizeMb = 25,
    VideoData? videoInfo,
    int? videoBytes,
  })  : _explicitVideoFile = videoFile,
        _explicitVideoInfo = videoInfo,
        _explicitVideoBytes = videoBytes;

  /// One-shot message for a snackbar; the page clears it once shown.
  final String? result;
  final bool isLoading;

  /// All videos chosen for batch compression.
  final List<VideoData> pickedVideos;

  /// Index of the currently viewed video in [pickedVideos].
  final int currentVideoIndex;

  final File? _explicitVideoFile;
  final VideoData? _explicitVideoInfo;
  final int? _explicitVideoBytes;

  /// Active video file (either the one at [currentVideoIndex] in [pickedVideos],
  /// or an explicitly set one).
  File? get videoFile => currentVideo?.videoFile ?? _explicitVideoFile;

  /// Active video info.
  VideoData? get videoInfo => currentVideo ?? _explicitVideoInfo;

  /// Active video size in bytes.
  int? get videoBytes => videoInfo?.fileBytes ?? _explicitVideoBytes;

  /// Currently active video in the carousel.
  VideoData? get currentVideo =>
      pickedVideos.isNotEmpty && currentVideoIndex < pickedVideos.length
          ? pickedVideos[currentVideoIndex]
          : (pickedVideos.isNotEmpty ? pickedVideos.first : null);

  /// Whether more than one video is chosen.
  bool get isBatch => pickedVideos.length > 1;

  final VideoPreview? preview;
  final bool isCompressing;

  /// "Compression Level" slider, 0..100.
  final int crfQuality;

  /// Overall percent complete across the whole batch (0..100).
  final int percentComplete;

  /// How many videos in the batch have completed compression.
  final int completedVideos;

  /// Total number of videos in the current compression batch.
  final int totalVideos;

  /// Progress percent of the video currently being compressed (0..100).
  final int currentVideoPercent;

  /// Time left for the running compression, once it can be told.
  final Duration? eta;

  /// The user chose Fast encoding (video hardware).
  final bool fastEncoding;

  /// This machine has video hardware that works for the current video.
  final bool fastEncodingAvailable;

  /// Fast encoding will really be used.
  bool get usesFastEncoding => fastEncoding && fastEncodingAvailable;

  /// The size worked out by compressing a few samples, and the choices
  /// ([estimateKey]) it was worked out for.
  final VideoSizeEstimate? estimate;
  final String? estimateKey;
  final VideoEstimateJob? estimateJob;
  final bool isEstimating;

  /// 0..100 while [isEstimating].
  final int estimatePercent;

  /// Everything that changes the result of compressing; an [estimate] is only
  /// valid for the same key.
  String get settingsKey => [
        mode.name,
        crfQuality,
        targetSizeMb,
        resolution.name,
        usesFastEncoding,
        presetIndex,
      ].join('|');

  /// The estimate, if it still matches the current choices.
  VideoSizeEstimate? get currentEstimate =>
      estimateKey == settingsKey ? estimate : null;

  /// Index into the FFmpeg presets ("Desired File Size" slider).
  final int presetIndex;
  final bool isFabOpen;

  /// The running compression, if any.
  final VideoCompressionJob? currentJob;

  final VideoMode mode;
  final VideoResolution resolution;

  /// Size to aim for in [VideoMode.targetSize], in megabytes.
  final int targetSizeMb;

  /// The shorter side of the selected video in pixels, if known.
  int? get sourceShortSide => videoInfo?.sourceShortSide;

  /// Whether [resolution] would make any video in the batch smaller. Original always can.
  bool canUseResolution(VideoResolution resolution) {
    final side = resolution.shortSide;
    if (side == null) return true;
    if (pickedVideos.isEmpty) {
      final source = sourceShortSide;
      return source == null || side < source;
    }
    return pickedVideos.any((v) {
      final source = v.sourceShortSide;
      return source == null || side < source;
    });
  }

  /// Whether a target of [mb] megabytes is smaller than the video itself.
  bool canTargetMb(int mb) {
    if (pickedVideos.isEmpty) {
      final bytes = videoBytes;
      return bytes == null || mb * 1000000 < bytes;
    }
    return pickedVideos.any((v) {
      final bytes = v.fileBytes;
      return bytes == null || mb * 1000000 < bytes;
    });
  }

  /// What is wrong with, or risky about, the current choices for this video.
  /// Empty until a video is picked.
  List<VideoSettingsWarning> get warnings {
    if (videoFile == null) return const [];
    return videoSettingsWarnings(
      aimsForSize: mode == VideoMode.targetSize,
      qualityPercent: crfQuality,
      targetMb: targetSizeMb,
      downscales: resolution.shortSide != null && canUseResolution(resolution),
      videoBytes: videoBytes,
      durationMs: videoInfo?.durationMs,
    );
  }

  /// True while a video is being loaded or compressed.
  bool get isBusy => isLoading || isCompressing;

  /// Nullable fields can be set to null by passing null explicitly.
  VideosState copyWith({
    Object? result = _unset,
    bool? isLoading,
    List<VideoData>? pickedVideos,
    int? currentVideoIndex,
    Object? videoFile = _unset,
    Object? preview = _unset,
    bool? isCompressing,
    int? crfQuality,
    int? percentComplete,
    int? completedVideos,
    int? totalVideos,
    int? currentVideoPercent,
    Object? eta = _unset,
    bool? fastEncoding,
    bool? fastEncodingAvailable,
    Object? estimate = _unset,
    Object? estimateKey = _unset,
    Object? estimateJob = _unset,
    bool? isEstimating,
    int? estimatePercent,
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
      pickedVideos: pickedVideos ?? this.pickedVideos,
      currentVideoIndex: currentVideoIndex ?? this.currentVideoIndex,
      videoFile:
          identical(videoFile, _unset) ? _explicitVideoFile : videoFile as File?,
      preview:
          identical(preview, _unset) ? this.preview : preview as VideoPreview?,
      isCompressing: isCompressing ?? this.isCompressing,
      crfQuality: crfQuality ?? this.crfQuality,
      percentComplete: percentComplete ?? this.percentComplete,
      completedVideos: completedVideos ?? this.completedVideos,
      totalVideos: totalVideos ?? this.totalVideos,
      currentVideoPercent: currentVideoPercent ?? this.currentVideoPercent,
      eta: identical(eta, _unset) ? this.eta : eta as Duration?,
      fastEncoding: fastEncoding ?? this.fastEncoding,
      fastEncodingAvailable: fastEncodingAvailable ?? this.fastEncodingAvailable,
      estimate: identical(estimate, _unset)
          ? this.estimate
          : estimate as VideoSizeEstimate?,
      estimateKey:
          identical(estimateKey, _unset) ? this.estimateKey : estimateKey as String?,
      estimateJob: identical(estimateJob, _unset)
          ? this.estimateJob
          : estimateJob as VideoEstimateJob?,
      isEstimating: isEstimating ?? this.isEstimating,
      estimatePercent: estimatePercent ?? this.estimatePercent,
      presetIndex: presetIndex ?? this.presetIndex,
      isFabOpen: isFabOpen ?? this.isFabOpen,
      currentJob: identical(currentJob, _unset)
          ? this.currentJob
          : currentJob as VideoCompressionJob?,
      mode: mode ?? this.mode,
      resolution: resolution ?? this.resolution,
      targetSizeMb: targetSizeMb ?? this.targetSizeMb,
      videoInfo:
          identical(videoInfo, _unset) ? _explicitVideoInfo : videoInfo as VideoData?,
      videoBytes:
          identical(videoBytes, _unset) ? _explicitVideoBytes : videoBytes as int?,
    );
  }
}
