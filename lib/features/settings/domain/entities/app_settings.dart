import 'package:petit/features/images/domain/entities/image_options.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';

/// The user's default compression settings. A new selection of images or a
/// new app launch starts from these; each tab can still be changed for the
/// job at hand.
///
/// Plain Dart with value equality, like the other entities.
class AppSettings {
  const AppSettings({
    this.imageQuality = 50,
    this.keepTransparency = true,
    this.removeLocation = false,
    this.videoUseTargetSize = false,
    this.videoQuality = 80,
    this.videoResolution = VideoResolution.original,
    this.videoPresetIndex = 1,
    this.videoTargetSizeMb = 25,
  });

  /// Highest valid index of the encoding speed choices (fast, balanced, slow).
  static const maxVideoPresetIndex = 2;

  /// Image quality, 0..100.
  final int imageQuality;
  final bool keepTransparency;
  final bool removeLocation;

  /// Videos: aim for a file size (true) or use the quality level (false).
  final bool videoUseTargetSize;

  /// Video compression level, 0..100.
  final int videoQuality;
  final VideoResolution videoResolution;

  /// Index of the encoding speed.
  final int videoPresetIndex;
  final int videoTargetSizeMb;

  ImageOptions get imageOptions => ImageOptions(
        keepTransparency: keepTransparency,
        removeLocation: removeLocation,
      );

  AppSettings copyWith({
    int? imageQuality,
    bool? keepTransparency,
    bool? removeLocation,
    bool? videoUseTargetSize,
    int? videoQuality,
    VideoResolution? videoResolution,
    int? videoPresetIndex,
    int? videoTargetSizeMb,
  }) {
    return AppSettings(
      imageQuality: imageQuality ?? this.imageQuality,
      keepTransparency: keepTransparency ?? this.keepTransparency,
      removeLocation: removeLocation ?? this.removeLocation,
      videoUseTargetSize: videoUseTargetSize ?? this.videoUseTargetSize,
      videoQuality: videoQuality ?? this.videoQuality,
      videoResolution: videoResolution ?? this.videoResolution,
      videoPresetIndex: videoPresetIndex ?? this.videoPresetIndex,
      videoTargetSizeMb: videoTargetSizeMb ?? this.videoTargetSizeMb,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.imageQuality == imageQuality &&
          other.keepTransparency == keepTransparency &&
          other.removeLocation == removeLocation &&
          other.videoUseTargetSize == videoUseTargetSize &&
          other.videoQuality == videoQuality &&
          other.videoResolution == videoResolution &&
          other.videoPresetIndex == videoPresetIndex &&
          other.videoTargetSizeMb == videoTargetSizeMb;

  @override
  int get hashCode => Object.hash(
        imageQuality,
        keepTransparency,
        removeLocation,
        videoUseTargetSize,
        videoQuality,
        videoResolution,
        videoPresetIndex,
        videoTargetSizeMb,
      );
}
