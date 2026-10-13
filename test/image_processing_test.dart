import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:petit/core/utils/image_processing.dart';

img.Image _rgba(int size, {required int alpha}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      image.setPixelRgba(x, y, 200, 40, 40, alpha);
    }
  }
  return image;
}

void main() {
  group('imageHasTransparency', () {
    test('is false for an image without an alpha channel', () {
      final image = img.Image(width: 4, height: 4, numChannels: 3);
      expect(imageHasTransparency(image), isFalse);
    });

    test('is false when every pixel is fully opaque', () {
      expect(imageHasTransparency(_rgba(4, alpha: 255)), isFalse);
    });

    test('is true when one pixel is not fully opaque', () {
      final image = _rgba(4, alpha: 255)..setPixelRgba(2, 2, 200, 40, 40, 0);
      expect(imageHasTransparency(image), isTrue);
    });

    test('is true for a half transparent image', () {
      expect(imageHasTransparency(_rgba(4, alpha: 128)), isTrue);
    });
  });

  group('flattenOnWhite', () {
    test('puts transparent pixels on white and keeps opaque ones', () {
      final image = _rgba(2, alpha: 255)..setPixelRgba(0, 0, 0, 0, 0, 0);

      final flat = flattenOnWhite(image);

      expect(flat.hasAlpha, isFalse);
      final cleared = flat.getPixel(0, 0);
      expect([cleared.r, cleared.g, cleared.b], [255, 255, 255]);
      final kept = flat.getPixel(1, 1);
      expect([kept.r, kept.g, kept.b], [200, 40, 40]);
    });
  });

  group('files', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('petit_pixels_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('hasTransparentPixels reads a PNG from disk', () async {
      final clear = File('${dir.path}/clear.png')
        ..writeAsBytesSync(img.encodePng(_rgba(8, alpha: 0)));
      final solid = File('${dir.path}/solid.png')
        ..writeAsBytesSync(img.encodePng(_rgba(8, alpha: 255)));

      expect(await hasTransparentPixels(clear.path), isTrue);
      expect(await hasTransparentPixels(solid.path), isFalse);
    });

    test('hasTransparentPixels treats an unreadable file as opaque', () async {
      final junk = File('${dir.path}/junk.png')..writeAsBytesSync([1, 2, 3]);
      expect(await hasTransparentPixels(junk.path), isFalse);
    });

    test('flattenToJpegBytes produces a JPEG of the same size', () async {
      final png = File('${dir.path}/clear.png')
        ..writeAsBytesSync(img.encodePng(_rgba(8, alpha: 0)));

      final bytes = await flattenToJpegBytes(png.path);

      final decoded = img.decodeJpg(bytes)!;
      expect([decoded.width, decoded.height], [8, 8]);
      final pixel = decoded.getPixel(4, 4);
      // Fully transparent source: white (JPEG rounding allowed).
      expect(pixel.r, greaterThan(240));
      expect(pixel.g, greaterThan(240));
      expect(pixel.b, greaterThan(240));
    });
  });
}
