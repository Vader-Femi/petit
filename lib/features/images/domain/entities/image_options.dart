/// Choices that apply to every image in a job, next to each image's quality.
///
/// Plain Dart, with value equality, so it can be a key for cached estimates.
class ImageOptions {
  const ImageOptions({
    this.keepTransparency = true,
    this.removeLocation = false,
  });

  /// Transparent PNG/WebP images stay transparent (saved as PNG, or WebP on
  /// Android). When false they are flattened onto white and saved as JPEG.
  final bool keepTransparency;

  /// Drops the photo's metadata, including where it was taken. The platform
  /// encoders cannot remove only the GPS tags, so the rest of the metadata
  /// (camera, date) goes too.
  final bool removeLocation;

  ImageOptions copyWith({bool? keepTransparency, bool? removeLocation}) {
    return ImageOptions(
      keepTransparency: keepTransparency ?? this.keepTransparency,
      removeLocation: removeLocation ?? this.removeLocation,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageOptions &&
          other.keepTransparency == keepTransparency &&
          other.removeLocation == removeLocation;

  @override
  int get hashCode => Object.hash(keepTransparency, removeLocation);
}
