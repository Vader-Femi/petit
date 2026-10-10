import 'dart:io';
import 'dart:isolate';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
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

/// Desktop implementation. JPEG, PNG and WebP are re-encoded as JPEG in pure
/// Dart (in a background isolate) so `quality` means the same thing as on
/// mobile. HEIC/HEIF is attempted through FFmpeg and reports a clear error if
/// the bundled FFmpeg cannot read it.
class DesktopImageCompressor implements ImageCompressor {
  @override
  Future<ImageSize> readSize(String path) async {
    try {
      if (isImageSizeGetterSupported(path)) {
        final size = ImageSizeGetter.getSizeResult(FileInput(File(path))).size;
        return ImageSize(size.width, size.height);
      }

      if (isHeif(path)) {
        final session = await FFprobeKit.getMediaInformation(path);
        final streams = session.getMediaInformation()?.getStreams() ?? [];
        for (final stream in streams) {
          final width = stream.getWidth();
          final height = stream.getHeight();
          if (width != null && height != null) {
            return ImageSize(width, height);
          }
        }
      }
    } catch (e) {
      debugPrint('Could not read image size for $path: $e');
    }
    // Same fallback as the mobile implementation.
    return const ImageSize(1080, 1080);
  }

  @override
  Future<File> compress(ImageData image, {required int quality}) async {
    try {
      final sourcePath = image.imageFile.path;
      if (!isCompressibleImage(sourcePath)) {
        throw const MediaException(
            "Unsupported- Only supports png,webp,jpeg,jpg,heic and heif");
      }

      final jobDir = await createJobDir();
      final baseName = p.basenameWithoutExtension(sourcePath);

      final decodePath = isHeif(sourcePath)
          ? await _convertHeifToJpeg(sourcePath, jobDir, baseName)
          : sourcePath;

      final outPath = p.join(jobDir.path, '${baseName}_compressed.jpg');
      await Isolate.run(() => _reencodeAsJpeg(decodePath, outPath, quality));

      final originalSize = await image.imageFile.length();
      final compressedSize = await File(outPath).length();

      // Compressed is larger or equal: hand back the original.
      return compressedSize < originalSize ? File(outPath) : image.imageFile;
    } on MediaException {
      rethrow;
    } catch (e) {
      throw MediaException('Error compressing image - $e');
    }
  }

  Future<String> _convertHeifToJpeg(
      String source, Directory jobDir, String baseName) async {
    final out = p.join(jobDir.path, '$baseName.jpg');
    try {
      final session = await FFmpegKit.executeWithArguments(
          ['-y', '-i', source, '-frames:v', '1', '-q:v', '2', out]);
      final code = await session.getReturnCode();
      if (ReturnCode.isSuccess(code) && await File(out).exists()) {
        return out;
      }
    } catch (e) {
      debugPrint('HEIC conversion failed: $e');
    }
    throw const MediaException(
        "HEIC/HEIF isn't supported on this platform yet. Convert the image to JPG or PNG first.");
  }
}

/// Runs in a background isolate: decode, apply EXIF orientation, write JPEG.
Future<void> _reencodeAsJpeg(
    String inPath, String outPath, int quality) async {
  final bytes = await File(inPath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const MediaException('Could not read this image.');
  }
  // Bake the EXIF orientation into the pixels so the result is upright
  // whether or not the encoder keeps the EXIF block.
  final upright = img.bakeOrientation(decoded);
  final jpg = img.encodeJpg(upright, quality: quality.clamp(1, 100).toInt());
  await File(outPath).writeAsBytes(jpg);
}
