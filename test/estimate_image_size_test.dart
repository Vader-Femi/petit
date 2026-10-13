import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/entities/image_options.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';
import 'package:petit/features/images/domain/usecases/estimate_image_size.dart';
import 'package:petit/features/images/domain/entities/image_size.dart';

/// Returns whatever [result] says, as the real compressors do.
class _StubCompressor implements ImageCompressor {
  _StubCompressor(this.result);

  final File Function(ImageData image) result;
  ImageOptions? seenOptions;
  int? seenQuality;

  @override
  Future<ImageSize> readSize(String path) async => const ImageSize(10, 10);

  @override
  Future<File> compress(
    ImageData image, {
    required int quality,
    ImageOptions options = const ImageOptions(),
  }) async {
    seenQuality = quality;
    seenOptions = options;
    return result(image);
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('petit_estimate_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ImageData imageOf(String name, int bytes) => ImageData(
        imageFile: File('${dir.path}/$name')
          ..writeAsBytesSync(List.filled(bytes, 0)),
        pixelWidth: 10,
        pixelHeight: 10,
        quality: 50,
      );

  File outputOf(String name, int bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(List.filled(bytes, 1));

  test('measures the compressed file and deletes it afterwards', () async {
    final image = imageOf('a.jpg', 1000);
    final out = outputOf('a_compressed.jpg', 250);
    final stub = _StubCompressor((_) => out);

    final estimate = await EstimateImageSizeUseCase(stub)(
      image,
      quality: 30,
      options: const ImageOptions(removeLocation: true),
    );

    expect(estimate.originalBytes, 1000);
    expect(estimate.estimatedBytes, 250);
    expect(estimate.formatLabel, 'JPG');
    expect(estimate.keepsOriginal, isFalse);
    expect(estimate.isLarger, isFalse);
    expect(estimate.savedFraction, closeTo(0.75, 1e-9));
    expect(stub.seenQuality, 30);
    expect(stub.seenOptions?.removeLocation, isTrue);
    expect(out.existsSync(), isFalse);
    expect(image.imageFile.existsSync(), isTrue);
  });

  test('reports that the original is kept, and never deletes it', () async {
    final image = imageOf('a.jpg', 1000);
    final stub = _StubCompressor((i) => i.imageFile);

    final estimate = await EstimateImageSizeUseCase(stub)(
      image,
      quality: 95,
      options: const ImageOptions(),
    );

    expect(estimate.keepsOriginal, isTrue);
    expect(estimate.estimatedBytes, 1000);
    expect(estimate.isLarger, isFalse);
    expect(estimate.savedFraction, 0.0);
    expect(image.imageFile.existsSync(), isTrue);
  });

  test('flags a result that is larger than the original', () async {
    final image = imageOf('a.jpg', 100);
    final stub = _StubCompressor((_) => outputOf('big.jpg', 150));

    final estimate = await EstimateImageSizeUseCase(stub)(
      image,
      quality: 95,
      options: const ImageOptions(removeLocation: true),
    );

    expect(estimate.isLarger, isTrue);
    expect(estimate.savedFraction, 0.0);
  });

  test('names the output format from the file extension', () async {
    final image = imageOf('logo.png', 1000);

    Future<String> labelFor(String outName) async {
      final stub = _StubCompressor((_) => outputOf(outName, 10));
      final estimate = await EstimateImageSizeUseCase(stub)(
        image,
        quality: 50,
        options: const ImageOptions(),
      );
      return estimate.formatLabel;
    }

    expect(await labelFor('x.png'), 'PNG');
    expect(await labelFor('x.webp'), 'WebP');
    expect(await labelFor('x.jpg'), 'JPG');
    expect(await labelFor('x.jpeg'), 'JPG');
  });
}
