import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/images/data/services/heif_arguments.dart';

void main() {
  group('buildHeifToJpegArguments', () {
    test('converts the first image to a high quality JPEG', () {
      final args = buildHeifToJpegArguments(
        inputPath: r'C:\Photos\IMG 0001.HEIC',
        outputPath: r'C:\work\IMG 0001.jpg',
      );

      expect(args, [
        '-y',
        '-i',
        r'C:\Photos\IMG 0001.HEIC',
        '-frames:v',
        '1',
        '-q:v',
        '2',
        r'C:\work\IMG 0001.jpg',
      ]);
    });

    test('keeps paths with spaces as single arguments', () {
      final args = buildHeifToJpegArguments(
        inputPath: '/home/me/my photos/a b.heic',
        outputPath: '/tmp/out dir/a b.jpg',
      );

      expect(args, contains('/home/me/my photos/a b.heic'));
      expect(args.last, '/tmp/out dir/a b.jpg');
    });

    test('has no filter unless a size limit is asked for', () {
      final args = buildHeifToJpegArguments(
          inputPath: 'a.heic', outputPath: 'a.jpg');
      expect(args, isNot(contains('-vf')));
    });

    test('a size limit adds a filter that only ever shrinks', () {
      final args = buildHeifToJpegArguments(
          inputPath: 'a.heic', outputPath: 'a.jpg', maxLongSide: 1600);

      final filter = args[args.indexOf('-vf') + 1];
      expect(filter, contains('min(iw\\,1600)'));
      expect(filter, contains('min(ih\\,1600)'));
      // The filter comes before the output name and after the input.
      expect(args.indexOf('-vf'), greaterThan(args.indexOf('-i')));
      expect(args.indexOf('-vf'), lessThan(args.length - 1));
    });

    test('commas in the filter are escaped for FFmpeg', () {
      final args = buildHeifToJpegArguments(
          inputPath: 'a.heic', outputPath: 'a.jpg', maxLongSide: 800);
      final filter = args[args.indexOf('-vf') + 1];

      // Every comma must be preceded by a backslash.
      expect(RegExp(r'(?<!\\),').hasMatch(filter), isFalse);
    });
  });
}
