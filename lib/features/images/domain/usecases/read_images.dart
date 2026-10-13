import 'dart:io';

import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';

/// Turns file paths (picked or shared) into [ImageData] with their size.
class ReadImagesUseCase {
  ReadImagesUseCase(this._compressor);

  final ImageCompressor _compressor;

  static const defaultQuality = 50;

  Future<List<ImageData>> call(
    List<String> paths, {
    int quality = defaultQuality,
  }) async {
    final images = <ImageData>[];
    for (final path in paths) {
      final size = await _compressor.readSize(path);
      images.add(ImageData(
        imageFile: File(path),
        pixelWidth: size.width,
        pixelHeight: size.height,
        quality: quality,
      ));
    }
    return images;
  }
}
