import 'dart:io';

import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/core/utils/media_formats.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';
import 'package:petit/features/images/domain/services/image_previewer.dart';

/// Turns file paths (picked or shared) into [ImageData] with their size, and a
/// preview where the original cannot be drawn.
class ReadImagesUseCase {
  ReadImagesUseCase(this._compressor, [this._previewer]);

  final ImageCompressor _compressor;
  final ImagePreviewer? _previewer;

  static const defaultQuality = 50;

  Future<List<ImageData>> call(
    List<String> paths, {
    int quality = defaultQuality,
  }) async {
    final images = <ImageData>[];
    for (final path in paths) {
      final size = await _compressor.readSize(path);
      // Only formats Flutter may not draw need one (HEIC).
      final preview =
          isHeif(path) ? await _previewer?.createPreview(path) : null;
      images.add(ImageData(
        imageFile: File(path),
        pixelWidth: size.width,
        pixelHeight: size.height,
        quality: quality,
        previewFile: preview,
      ));
    }
    return images;
  }
}
