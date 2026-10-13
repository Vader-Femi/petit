/// What compressing one image with the current settings would produce.
class ImageSizeEstimate {
  const ImageSizeEstimate({
    required this.originalBytes,
    required this.estimatedBytes,
    required this.formatLabel,
    required this.keepsOriginal,
  });

  final int originalBytes;

  /// Size of the file that would be saved.
  final int estimatedBytes;

  /// Format of the saved file, e.g. `JPG`, `PNG` or `WebP`.
  final String formatLabel;

  /// True when compressing would not make the file smaller and the original is
  /// saved unchanged.
  final bool keepsOriginal;

  /// The result is bigger than the original. Only happens when the original
  /// cannot be kept, for example because location data has to be removed.
  bool get isLarger => !keepsOriginal && estimatedBytes > originalBytes;

  bool get isPng => formatLabel == 'PNG';

  /// Fraction (0..1) of the original size that would be saved.
  double get savedFraction => originalBytes <= 0 || keepsOriginal
      ? 0.0
      : ((originalBytes - estimatedBytes) / originalBytes)
          .clamp(0.0, 1.0)
          .toDouble();
}
