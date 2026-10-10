import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:heif_converter_plus/heif_converter.dart';
import 'package:image/image.dart' as img;
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path/path.dart' as p;
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/utils/media_formats.dart';
import 'package:petit/core/utils/work_dir.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
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
  Future<File> compress(ImageData image, {required int quality}) async {
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

      if (!isJpeg(filePath)) {
        final jpgFile = File(p.join(jobDir.path, "$baseName.jpg"));

        if (isHeif(filePath)) {
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
        } else {
          //Re encode png/webp to jpg
          final decoded = img.decodeImage(await image.imageFile.readAsBytes())!;
          await jpgFile.writeAsBytes(img.encodeJpg(decoded));
        }

        filePath = jpgFile.path;
      }

      final outPath = p.join(
          jobDir.path, "${baseName}_compressed${p.extension(filePath)}");

      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        minWidth: image.pixelWidth,
        minHeight: image.pixelHeight,
        quality: quality,
        keepExif: true,
      );

      if (compressedImage == null) {
        throw const MediaException("Error compressing image!");
      }

      final originalSize = await File(filePath).length();
      final compressedSize = await compressedImage.length();

      // Compressed is larger or equal: hand back the original.
      return compressedSize < originalSize
          ? File(compressedImage.path)
          : image.imageFile;
    } on MediaException {
      rethrow;
    } catch (e) {
      throw MediaException("Error compressing image - $e");
    }
  }
}
