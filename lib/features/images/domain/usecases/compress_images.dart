import 'dart:io';

import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';

class BatchProgress {
  final int completedSteps;
  final int totalSteps;
  final int percent;

  const BatchProgress({
    required this.completedSteps,
    required this.totalSteps,
    required this.percent,
  });
}

class ImageBatchResult {
  final int originalBytes;
  final int compressedBytes;
  final String destinationLabel;

  const ImageBatchResult({
    required this.originalBytes,
    required this.compressedBytes,
    required this.destinationLabel,
  });

  int get savedBytes => originalBytes - compressedBytes;

  /// Fraction (0..1) of the original size that was saved.
  double get savedFraction => originalBytes <= 0
      ? 0.0
      : (savedBytes / originalBytes).clamp(0, 1).toDouble();
}

/// Compresses and saves a batch of images, reporting progress as it goes.
///
/// Failures on a single image are reported through [onError] and do not stop
/// the batch. Clearing temporary files is left to the caller so it can tear
/// down its UI first.
class CompressImagesUseCase {
  CompressImagesUseCase(this._compressor, this._saver);

  final ImageCompressor _compressor;
  final MediaSaver _saver;

  Future<ImageBatchResult> call({
    required List<ImageData> images,
    int? globalQuality,
    required bool Function() isCancelled,
    required void Function(BatchProgress progress) onProgress,
    required void Function(String message) onError,
  }) async {
    // May ask the user where to save; throws MediaException if they decline.
    await _saver.prepare();

    final total = images.length;
    var progress = total == 1 ? 50 : 0;
    var sizeBefore = 0;
    var sizeAfter = 0;

    for (final (index, image) in images.indexed) {
      if (isCancelled()) break;

      onProgress(BatchProgress(
        completedSteps: index,
        totalSteps: total,
        percent: progress,
      ));

      final originalSize = await image.imageFile.length();
      sizeBefore += originalSize;

      if (isCancelled()) break;

      final File compressed;
      try {
        compressed = await _compressor.compress(
          image,
          quality: globalQuality ?? image.quality,
        );
      } on MediaException catch (e) {
        sizeBefore -= originalSize;
        onError(e.message);
        continue;
      } catch (e) {
        sizeBefore -= originalSize;
        onError("Error compressing image - $e");
        continue;
      }

      if (isCancelled()) break;

      try {
        await _saver.saveImage(compressed.path);
      } catch (e) {
        onError("Error ocurred - $e");
      }

      sizeAfter += await compressed.length();

      if (isCancelled()) break;

      progress = (((index + 1) / total) * 100).round();
      onProgress(BatchProgress(
        completedSteps: index + 1,
        totalSteps: total,
        percent: progress,
      ));
    }

    return ImageBatchResult(
      originalBytes: sizeBefore,
      compressedBytes: sizeAfter,
      destinationLabel: _saver.imageDestinationLabel,
    );
  }
}
