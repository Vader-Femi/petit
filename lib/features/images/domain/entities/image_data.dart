import 'dart:io';

/// An image selected for compression.
///
/// Plain Dart: value equality is implemented here instead of through a
/// state-management mixin, so the domain layer does not depend on one.
class ImageData {
  final File imageFile;
  final int pixelWidth;
  final int pixelHeight;
  final int quality;

  const ImageData({
    required this.imageFile,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.quality,
  });

  ImageData copyWith({
    File? imageFile,
    int? pixelWidth,
    int? pixelHeight,
    int? quality,
  }) {
    return ImageData(
      imageFile: imageFile ?? this.imageFile,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
      quality: quality ?? this.quality,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageData &&
          other.imageFile == imageFile &&
          other.pixelHeight == pixelHeight &&
          other.pixelWidth == pixelWidth &&
          other.quality == quality;

  @override
  int get hashCode => Object.hash(imageFile, pixelHeight, pixelWidth, quality);
}
