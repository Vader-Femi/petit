import 'dart:io';
import 'dart:isolate';

import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:flutter/foundation.dart';
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
import 'package:petit/features/images/data/services/desktop_heif_converter.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';

/// Desktop implementation. JPEG, PNG and WebP are re-encoded as JPEG in pure
/// Dart (in a background isolate) so `quality` means the same thing as on
/// mobile. A PNG or WebP that really has transparent pixels stays a (lossless)
/// PNG instead, because JPEG cannot hold transparency and the pure Dart
/// package cannot write WebP. JPEGs are written with 4:2:0 chroma, as phones
/// do. HEIC/HEIF is converted first by [DesktopHeifConverter] (ImageIO on
/// macOS, the bundled FFmpeg everywhere), with a clear error if that fails.
class DesktopImageCompressor implements ImageCompressor {
  DesktopImageCompressor({DesktopHeifConverter? heifConverter})
      : _heif = heifConverter ?? DesktopHeifConverter();

  final DesktopHeifConverter _heif;

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
  Future<File> compress(
    ImageData image, {
    required int quality,
    ImageOptions options = const ImageOptions(),
  }) async {
    try {
      final sourcePath = image.imageFile.path;
      if (!isCompressibleImage(sourcePath)) {
        throw const MediaException(
            "Unsupported- Only supports png,webp,jpeg,jpg,heic and heif");
      }

      final jobDir = await createJobDir();
      final baseName = p.basenameWithoutExtension(sourcePath);

      final isHeifSource = isHeif(sourcePath);
      final decodePath = isHeifSource
          ? await _convertHeifToJpeg(sourcePath, jobDir, baseName)
          : sourcePath;

      // The isolate picks .png or .jpg, depending on the pixels. Plain values
      // only: nothing but these is copied into the isolate.
      final outBase = p.join(jobDir.path, '${baseName}_compressed');
      final keepTransparency = options.keepTransparency;
      final removeLocation = options.removeLocation;
      final outPath = await Isolate.run(() =>
          _reencode(decodePath, outBase, quality, keepTransparency, removeLocation));

      if (isHeifSource) {
        // Only a stepping stone; this runs for every estimate too.
        try {
          await File(decodePath).delete();
        } on FileSystemException {
          // Removed with the rest of the work folder later.
        }
      }

      final originalSize = await image.imageFile.length();
      final compressedSize = await File(outPath).length();

      // Compressed is larger or equal: hand back the original, unless the
      // user asked for the location data to go, which only the new file
      // satisfies.
      if (compressedSize < originalSize || options.removeLocation) {
        return File(outPath);
      }
      return image.imageFile;
    } on MediaException {
      rethrow;
    } catch (e) {
      throw MediaException('Error compressing image - $e');
    }
  }

  Future<String> _convertHeifToJpeg(
      String source, Directory jobDir, String baseName) async {
    final out = p.join(jobDir.path, '$baseName.jpg');
    if (await _heif.toJpeg(source, out)) return out;
    throw const MediaException(
        "This HEIC/HEIF photo could not be read. Convert it to JPG or PNG first.");
  }
}

/// Runs in a background isolate: decode, apply EXIF orientation, optionally
/// drop the metadata, then write a PNG (transparent images when asked to keep
/// transparency) or a JPEG. Returns the path written.
Future<String> _reencode(
  String inPath,
  String outBase,
  int quality,
  bool keepTransparency,
  bool removeLocation,
) async {
  final bytes = await File(inPath).readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const MediaException('Could not read this image.');
  }
  // Bake the EXIF orientation into the pixels so the result is upright
  // whether or not the encoder keeps the EXIF block.
  final upright = img.bakeOrientation(decoded);
  if (removeLocation) {
    // The encoders write whatever EXIF the image carries; an empty block
    // means no GPS position (and no camera or date either).
    upright.exif = img.ExifData();
  }

  final transparent = imageHasTransparency(upright);

  if (transparent && keepTransparency) {
    final outPath = '$outBase.png';
    await File(outPath).writeAsBytes(img.encodePng(upright, level: 9));
    return outPath;
  }

  final flat = transparent ? flattenOnWhite(upright) : upright;
  final outPath = '$outBase.jpg';
  await File(outPath)
      .writeAsBytes(img.encodeJpg(flat,
          quality: quality.clamp(1, 100).toInt(),
          // 4:2:0, like the phone encoders: a quarter of the colour detail
          // the eye cannot see, and noticeably smaller files than the 4:4:4
          // this package writes by default.
          chroma: img.JpegChroma.yuv420));
  return outPath;
}
