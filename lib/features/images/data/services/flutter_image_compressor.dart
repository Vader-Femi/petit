import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:heif_converter_plus/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path/path.dart' as p;
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/utils/image_processing.dart';
import 'package:petit/core/utils/media_formats.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/core/utils/work_dir.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/entities/image_options.dart';
import 'package:petit/features/images/domain/entities/image_size.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';

/// Mobile implementation: flutter_image_compress plus heif_converter_plus.
class FlutterImageCompressor implements ImageCompressor {
  @override
  Future<ImageSize> readSize(String path) async {
    var width = 1080;
    var height = 1080;

    String? readablePath;
    if (isImageSizeGetterSupported(path)) {
      readablePath = path;
    } else if (isHeif(path)) {
      // image_size_getter cannot read HEIC/HEIF, so convert first.
      readablePath = await HeifConverter.convert(path, format: "jpg");
    }

    if (readablePath != null) {
      final size =
          ImageSizeGetter.getSizeResult(FileInput(File(readablePath))).size;
      width = size.width;
      height = size.height;
    }

    return ImageSize(width, height);
  }

  @override
  Future<File> compress(
    ImageData image, {
    required int quality,
    ImageOptions options = const ImageOptions(),
  }) async {
    try {
      var filePath = image.imageFile.path;
      if (!isCompressibleImage(filePath)) {
        throw const MediaException(
            "Unsupported- Only supports png,webp,jpeg,jpg,heic and heif");
      }

      // Intermediate and output files go into a private job folder, never
      // next to the user's original file (which could overwrite a real photo
      // on desktop, e.g. photo.png -> photo.jpg).
      final jobDir = await createJobDir();
      final baseName = p.basenameWithoutExtension(filePath);

      var format = CompressFormat.jpeg;
      File? intermediate;

      if (isHeif(filePath)) {
        final jpgFile = File(p.join(jobDir.path, "$baseName.jpg"));
        final jpgPath = await HeifConverter.convert(filePath, format: "jpg");
        if (jpgPath == null) {
          throw const MediaException("Invalid HEIC/HEIF file");
        }

        //Resize, Rotate, then replace the file path
        final jpgImage = img.decodeImage(await File(jpgPath).readAsBytes());
        final resizedImage = img.copyResize(jpgImage!,
            width: image.pixelWidth, height: image.pixelHeight);
        // TODO: this hardcoded 90 degree rotation is kept from the old code;
        // verify it per platform (orientation differs on desktop).
        final rotatedJpgImage = img.copyRotate(resizedImage, angle: 90);

        await jpgFile.writeAsBytes(img.encodeJpg(rotatedJpgImage));
        intermediate = jpgFile;
        filePath = jpgFile.path;
      } else if (!isJpeg(filePath)) {
        final keepAlpha = options.keepTransparency &&
            await hasTransparentPixels(filePath);

        if (keepAlpha) {
          // The platform encoder reads the original and keeps its alpha
          // channel. Android's gallery takes WebP, which also honours the
          // quality slider; iOS Photos does not, so it gets lossless PNG.
          format = PlatformInfo.isAndroid
              ? CompressFormat.webp
              : CompressFormat.png;
        } else {
          // Opaque (or flattened) image: JPEG, transparent areas on white.
          final jpgFile = File(p.join(jobDir.path, "$baseName.jpg"));
          await jpgFile.writeAsBytes(await flattenToJpegBytes(filePath));
          intermediate = jpgFile;
          filePath = jpgFile.path;
        }
      }

      final extension = switch (format) {
        CompressFormat.webp => '.webp',
        CompressFormat.png => '.png',
        _ => p.extension(filePath),
      };
      final outPath = p.join(jobDir.path, "${baseName}_compressed$extension");

      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        minWidth: image.pixelWidth,
        minHeight: image.pixelHeight,
        quality: quality,
        format: format,
        keepExif: !options.removeLocation,
      );

      if (compressedImage == null) {
        throw const MediaException("Error compressing image!");
      }

      final compressedFile = File(compressedImage.path);

      // The intermediate JPEG is only a stepping stone; keep the work folder
      // small, which matters when this runs for every slider change.
      if (intermediate != null) {
        try {
          await intermediate.delete();
        } on FileSystemException {
          // Removed with the rest of the work folder later.
        }
      }

      // Compressed is larger or equal: hand back the original, unless the
      // user asked for the location data to go, which only the new file
      // satisfies.
      final originalSize = await image.imageFile.length();
      final compressedSize = await compressedFile.length();
      if (compressedSize < originalSize || options.removeLocation) {
        return compressedFile;
      }
      return image.imageFile;
    } on MediaException {
      rethrow;
    } catch (e) {
      throw MediaException("Error compressing image - $e");
    }
  }
}
