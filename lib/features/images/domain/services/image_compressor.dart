import 'dart:io';

import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/entities/image_size.dart';

abstract interface class ImageCompressor {
  /// Pixel size of the image at [path] (HEIC/HEIF included). Implementations
  /// return 1080x1080 when the size cannot be determined.
  Future<ImageSize> readSize(String path);

  /// Compresses [image] and returns the file that should be saved: the
  /// compressed file, or the original when compression did not make it
  /// smaller. Throws a [MediaException] with a user-facing message on failure.
  Future<File> compress(ImageData image, {required int quality});
}
