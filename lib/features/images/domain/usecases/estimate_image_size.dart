import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/entities/image_options.dart';
import 'package:petit/features/images/domain/entities/image_size_estimate.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';

/// Works out how big one image would be after compression by compressing it
/// for real and measuring the result. That is exact, not a guess, and it keeps
/// the estimate consistent with the real job whatever the platform does.
///
/// The test output is deleted again, so estimating leaves no big files behind.
class EstimateImageSizeUseCase {
  EstimateImageSizeUseCase(this._compressor);

  final ImageCompressor _compressor;

  Future<ImageSizeEstimate> call(
    ImageData image, {
    required int quality,
    required ImageOptions options,
  }) async {
    final originalBytes = await image.imageFile.length();
    final output = await _compressor.compress(
      image,
      quality: quality,
      options: options,
    );

    final keepsOriginal = output.path == image.imageFile.path;
    final estimatedBytes = keepsOriginal ? originalBytes : await output.length();
    final label = _formatLabel(output.path);

    if (!keepsOriginal) {
      // Only the output file: never delete anything that is not ours.
      try {
        await output.delete();
      } on FileSystemException {
        // Cleaned up with the rest of the work folder later.
      }
    }

    return ImageSizeEstimate(
      originalBytes: originalBytes,
      estimatedBytes: estimatedBytes,
      formatLabel: label,
      keepsOriginal: keepsOriginal,
    );
  }

  static String _formatLabel(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.png':
        return 'PNG';
      case '.webp':
        return 'WebP';
      case '.heic':
      case '.heif':
        return 'HEIC';
      default:
        return 'JPG';
    }
  }
}
