import 'dart:io';

import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/entities/image_options.dart';
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

  /// Folder the user can open, or null (see [MediaSaver.destinationFolder]).
  final String? destinationFolder;

  const ImageBatchResult({
    required this.originalBytes,
    required this.compressedBytes,
    required this.destinationLabel,
    this.destinationFolder,
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

  /// [concurrency] is how many images are compressed at the same time. With
  /// more than one, progress reports "images finished so far", and images may
  /// finish in a different order than they were given.
  Future<ImageBatchResult> call({
    required List<ImageData> images,
    int? globalQuality,
    ImageOptions options = const ImageOptions(),
    int concurrency = 1,
    required bool Function() isCancelled,
    required void Function(BatchProgress progress) onProgress,
    required void Function(String message) onError,
  }) async {
    // May ask the user where to save; throws MediaException if they decline.
    await _saver.prepare();

    final total = images.length;
    var percent = total == 1 ? 50 : 0;
    var finished = 0;
    var sizeBefore = 0;
    var sizeAfter = 0;
    var next = 0;

    void report() => onProgress(BatchProgress(
          completedSteps: finished,
          totalSteps: total,
          percent: percent,
        ));

    void finishOne() {
      finished++;
      percent = ((finished / total) * 100).round();
      report();
    }

    // Each worker takes the next image, compresses and saves it, and repeats.
    // Everything between two awaits runs without interruption, so the shared
    // counters need no locking.
    Future<void> worker() async {
      while (!isCancelled() && next < total) {
        final image = images[next++];

        report();

        final originalSize = await image.imageFile.length();
        sizeBefore += originalSize;

        if (isCancelled()) return;

        final File compressed;
        try {
          compressed = await _compressor.compress(
            image,
            quality: globalQuality ?? image.quality,
            options: options,
          );
        } on MediaException catch (e) {
          sizeBefore -= originalSize;
          onError(e.message);
          finishOne();
          continue;
        } catch (e) {
          sizeBefore -= originalSize;
          onError("Error compressing image - $e");
          finishOne();
          continue;
        }

        if (isCancelled()) return;

        try {
          await _saver.saveImage(compressed.path);
        } catch (e) {
          onError("Error ocurred - $e");
        }

        sizeAfter += await compressed.length();

        if (isCancelled()) return;

        finishOne();
      }
    }

    final workers = concurrency.clamp(1, total < 1 ? 1 : total).toInt();
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);

    return ImageBatchResult(
      originalBytes: sizeBefore,
      compressedBytes: sizeAfter,
      destinationLabel: _saver.imageDestinationLabel,
      destinationFolder: _saver.destinationFolder,
    );
  }
}
