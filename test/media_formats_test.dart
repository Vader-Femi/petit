import 'package:flutter_test/flutter_test.dart';
import 'package:petit/core/utils/media_formats.dart';

void main() {
  group('media_formats', () {
    test('detects common image formats case-insensitively', () {
      expect(isJpeg('/a/b/photo.jpg'), isTrue);
      expect(isJpeg('/a/b/photo.JPEG'), isTrue);
      expect(isHeif('/a/b/photo.HEIC'), isTrue);
      expect(isHeif('/a/b/photo.heif'), isTrue);
      expect(isImageSizeGetterSupported('C:\\Users\\Jo Doe\\pic.PNG'), isTrue);
    });

    test('does not match the dot as a wildcard', () {
      // Old regex `.png` matched "_png" and skipped the HEIC conversion.
      expect(isImageSizeGetterSupported('/a/photo_png.heic'), isFalse);
      expect(isHeif('/a/photo_png.heic'), isTrue);
    });

    test('recognises common video formats', () {
      expect(isVideoFile('/a/clip.MP4'), isTrue);
      expect(isVideoFile('C:\\Videos\\movie.mkv'), isTrue);
      expect(isVideoFile('/a/clip.mp4.txt'), isFalse);
      expect(isVideoFile('/a/photo.jpg'), isFalse);
    });

    test('only matches at the end of the path', () {
      expect(isImageSizeGetterSupported('/a/.png_folder/file.heic'), isFalse);
      expect(isCompressibleImage('/a/b/file.gif'), isFalse);
      expect(isCompressibleImage('/a/b/file.webp'), isTrue);
    });
  });
}
