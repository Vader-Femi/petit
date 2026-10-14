import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/entities/image_options.dart';
import 'package:petit/features/images/domain/entities/image_size.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';
import 'package:petit/features/images/domain/services/image_previewer.dart';
import 'package:petit/features/images/domain/usecases/compress_images.dart';
import 'package:petit/features/images/domain/usecases/read_images.dart';

class FakeImageCompressor implements ImageCompressor {
  FakeImageCompressor(this.dir, {this.failOn = const {}});

  final Directory dir;
  final Set<String> failOn;
  final qualities = <int>[];
  final optionsSeen = <ImageOptions>[];

  @override
  Future<ImageSize> readSize(String path) async => const ImageSize(640, 480);

  @override
  Future<File> compress(
    ImageData image, {
    required int quality,
    ImageOptions options = const ImageOptions(),
  }) async {
    qualities.add(quality);
    optionsSeen.add(options);
    if (failOn.contains(image.imageFile.path)) {
      throw const MediaException('boom');
    }
    // "Compressed" output is 40 bytes, smaller than the 100-byte originals.
    final out = File('${dir.path}/${qualities.length}_out.bin');
    await out.writeAsBytes(List.filled(40, 1));
    return out;
  }
}

/// Holds every compression open until the test lets it finish, and counts how
/// many are in flight at once.
/// Polls until [condition] holds, failing the test if it never does.
Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting.');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class GatedImageCompressor implements ImageCompressor {
  GatedImageCompressor(this.dir);

  final Directory dir;
  final gates = <Completer<void>>[];
  int inFlight = 0;
  int maxInFlight = 0;
  int started = 0;

  @override
  Future<ImageSize> readSize(String path) async => const ImageSize(640, 480);

  @override
  Future<File> compress(
    ImageData image, {
    required int quality,
    ImageOptions options = const ImageOptions(),
  }) async {
    final number = ++started;
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    inFlight--;
    return File('${dir.path}/${number}_out.bin')
      ..writeAsBytesSync(List.filled(40, 1));
  }
}

class FakePreviewer implements ImagePreviewer {
  final asked = <String>[];

  @override
  Future<File?> createPreview(String path) async {
    asked.add(path);
    return File('$path.preview.jpg');
  }
}

class FakeSaver implements MediaSaver {
  FakeSaver({this.declineToPrepare = false});

  final bool declineToPrepare;
  int prepareCalls = 0;
  final saved = <String>[];

  @override
  Future<void> prepare() async {
    prepareCalls++;
    if (declineToPrepare) {
      throw const MediaException('No output folder selected.');
    }
  }

  @override
  Future<void> saveImage(String path) async => saved.add(path);

  @override
  Future<void> saveVideo(String path) async => saved.add(path);

  @override
  String? get destinationFolder => '/out/folder';

  @override
  String get imageDestinationLabel => 'Photos';

  @override
  String get videoDestinationLabel => 'Photos';
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('petit_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ImageData makeImage(String name, {int quality = 50}) {
    final file = File('${dir.path}/$name')..writeAsBytesSync(List.filled(100, 0));
    return ImageData(
        imageFile: file, pixelWidth: 10, pixelHeight: 10, quality: quality);
  }

  group('ImageData', () {
    test('has value equality like the old SuperModel version', () {
      final file = File('a.jpg');
      final a = ImageData(
          imageFile: file, pixelWidth: 1, pixelHeight: 2, quality: 3);
      final b = a.copyWith();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(quality: 4), isNot(a));
    });
  });

  group('ReadImagesUseCase', () {
    test('reads the size of every path with the default quality', () async {
      final result = await ReadImagesUseCase(FakeImageCompressor(dir))(
          ['/x/a.jpg', '/x/b.png']);
      expect(result.length, 2);
      expect(result.first.pixelWidth, 640);
      expect(result.first.quality, ReadImagesUseCase.defaultQuality);
    });
  });

  group('ReadImagesUseCase previews', () {
    test('only HEIC photos get a preview', () async {
      final previewer = FakePreviewer();

      final result = await ReadImagesUseCase(
          FakeImageCompressor(dir), previewer)(
        ['/x/a.jpg', '/x/b.HEIC', '/x/c.png', '/x/d.heif'],
      );

      expect(previewer.asked, ['/x/b.HEIC', '/x/d.heif']);
      expect(result[0].previewFile, isNull);
      expect(result[1].previewFile?.path, '/x/b.HEIC.preview.jpg');
      expect(result[2].previewFile, isNull);
      expect(result[3].previewFile?.path, '/x/d.heif.preview.jpg');
    });

    test('works without a previewer', () async {
      final result =
          await ReadImagesUseCase(FakeImageCompressor(dir))(['/x/a.heic']);
      expect(result.single.previewFile, isNull);
    });

    test('the preview is part of equality', () {
      final a = ImageData(
          imageFile: File('a.heic'), pixelWidth: 1, pixelHeight: 1, quality: 1);
      final b = a.copyWith(previewFile: File('p.jpg'));
      expect(a, isNot(b));
      expect(b, b.copyWith());
    });
  });

  group('CompressImagesUseCase', () {
    test('reports progress and totals for two images', () async {
      final compressor = FakeImageCompressor(dir);
      final saver = FakeSaver();
      final progress = <String>[];

      final result = await CompressImagesUseCase(compressor, saver)(
        images: [makeImage('a.jpg'), makeImage('b.jpg')],
        isCancelled: () => false,
        onProgress: (p) =>
            progress.add('${p.completedSteps}/${p.totalSteps}@${p.percent}'),
        onError: (_) => fail('no errors expected'),
      );

      expect(progress, ['0/2@0', '1/2@50', '1/2@50', '2/2@100']);
      expect(saver.saved.length, 2);
      expect(result.originalBytes, 200);
      expect(result.compressedBytes, 80);
      expect(result.savedBytes, 120);
      expect(result.savedFraction, closeTo(0.6, 1e-9));
      expect(result.destinationLabel, 'Photos');
      expect(result.destinationFolder, '/out/folder');
    });

    test('a single image starts at 50 percent', () async {
      final progress = <int>[];
      await CompressImagesUseCase(FakeImageCompressor(dir), FakeSaver())(
        images: [makeImage('a.jpg')],
        isCancelled: () => false,
        onProgress: (p) => progress.add(p.percent),
        onError: (_) {},
      );
      expect(progress.first, 50);
      expect(progress.last, 100);
    });

    test('a failing image is reported and left out of the totals', () async {
      final bad = makeImage('bad.jpg');
      final errors = <String>[];

      final result = await CompressImagesUseCase(
        FakeImageCompressor(dir, failOn: {bad.imageFile.path}),
        FakeSaver(),
      )(
        images: [bad, makeImage('good.jpg')],
        isCancelled: () => false,
        onProgress: (_) {},
        onError: errors.add,
      );

      expect(errors, ['boom']);
      expect(result.originalBytes, 100);
      expect(result.compressedBytes, 40);
    });

    test('stops when cancelled', () async {
      final saver = FakeSaver();

      final result = await CompressImagesUseCase(
          FakeImageCompressor(dir), saver)(
        images: [makeImage('a.jpg'), makeImage('b.jpg'), makeImage('c.jpg')],
        isCancelled: () => saver.saved.isNotEmpty,
        onProgress: (_) {},
        onError: (_) {},
      );

      expect(saver.saved.length, 1);
      expect(result.originalBytes, 100);
      expect(result.compressedBytes, 40);
    });

    test('asks the saver where to save once, before compressing', () async {
      final compressor = FakeImageCompressor(dir);
      final saver = FakeSaver();

      await CompressImagesUseCase(compressor, saver)(
        images: [makeImage('a.jpg'), makeImage('b.jpg')],
        isCancelled: () => false,
        onProgress: (_) {},
        onError: (_) {},
      );

      expect(saver.prepareCalls, 1);
    });

    test('does no work when the user declines to choose a destination',
        () async {
      final compressor = FakeImageCompressor(dir);
      final progress = <BatchProgress>[];

      await expectLater(
        CompressImagesUseCase(compressor, FakeSaver(declineToPrepare: true))(
          images: [makeImage('a.jpg')],
          isCancelled: () => false,
          onProgress: progress.add,
          onError: (_) {},
        ),
        throwsA(isA<MediaException>()
            .having((e) => e.message, 'message', 'No output folder selected.')),
      );

      expect(compressor.qualities, isEmpty);
      expect(progress, isEmpty);
    });

    group('several at once', () {
      /// Lets the compressions finish, one by one, as they start. Reading file
      /// sizes is real I/O, so wait for each start instead of counting turns.
      Future<void> finishAll(GatedImageCompressor compressor, int count) async {
        for (var done = 0; done < count; done++) {
          await waitUntil(() => compressor.gates.length > done);
          compressor.gates[done].complete();
        }
      }

      test('never runs more than the allowed number at a time', () async {
        final compressor = GatedImageCompressor(dir);
        final run = CompressImagesUseCase(compressor, FakeSaver())(
          images: [for (var i = 0; i < 5; i++) makeImage('$i.jpg')],
          concurrency: 2,
          isCancelled: () => false,
          onProgress: (_) {},
          onError: (_) {},
        );

        await waitUntil(() => compressor.inFlight == 2);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(compressor.started, 2, reason: 'the third waits for a free worker');

        await finishAll(compressor, 5);
        final result = await run;

        expect(compressor.maxInFlight, 2);
        expect(result.originalBytes, 500);
        expect(result.compressedBytes, 200);
      });

      test('one at a time by default', () async {
        final compressor = GatedImageCompressor(dir);
        final run = CompressImagesUseCase(compressor, FakeSaver())(
          images: [for (var i = 0; i < 3; i++) makeImage('$i.jpg')],
          isCancelled: () => false,
          onProgress: (_) {},
          onError: (_) {},
        );

        await finishAll(compressor, 3);
        await run;

        expect(compressor.maxInFlight, 1);
      });

      test('more workers than images is fine, and zero means one', () async {
        for (final concurrency in [10, 0, -3]) {
          final compressor = FakeImageCompressor(dir);
          final saver = FakeSaver();
          await CompressImagesUseCase(compressor, saver)(
            images: [makeImage('a$concurrency.jpg'), makeImage('b$concurrency.jpg')],
            concurrency: concurrency,
            isCancelled: () => false,
            onProgress: (_) {},
            onError: (_) {},
          );
          expect(saver.saved.length, 2, reason: 'concurrency $concurrency');
        }
      });

      test('progress counts finished images and ends at 100', () async {
        final compressor = FakeImageCompressor(dir);
        final seen = <BatchProgress>[];

        await CompressImagesUseCase(compressor, FakeSaver())(
          images: [for (var i = 0; i < 4; i++) makeImage('$i.jpg')],
          concurrency: 3,
          isCancelled: () => false,
          onProgress: seen.add,
          onError: (_) {},
        );

        final completed = seen.map((p) => p.completedSteps).toList();
        final sorted = [...completed]..sort();
        expect(completed, sorted, reason: 'never goes backwards');
        expect(seen.last.completedSteps, 4);
        expect(seen.last.percent, 100);
        expect(seen.every((p) => p.totalSteps == 4), isTrue);
      });

      test('a failing image does not stop the others', () async {
        final bad = makeImage('bad.jpg');
        final errors = <String>[];
        final saver = FakeSaver();

        final result = await CompressImagesUseCase(
          FakeImageCompressor(dir, failOn: {bad.imageFile.path}),
          saver,
        )(
          images: [makeImage('a.jpg'), bad, makeImage('c.jpg')],
          concurrency: 3,
          isCancelled: () => false,
          onProgress: (_) {},
          onError: errors.add,
        );

        expect(errors, ['boom']);
        expect(saver.saved.length, 2);
        expect(result.originalBytes, 200);
        expect(result.compressedBytes, 80);
      });

      test('cancelling stops starting new images', () async {
        final compressor = FakeImageCompressor(dir);
        final saver = FakeSaver();

        await CompressImagesUseCase(compressor, saver)(
          images: [for (var i = 0; i < 8; i++) makeImage('$i.jpg')],
          concurrency: 2,
          isCancelled: () => saver.saved.isNotEmpty,
          onProgress: (_) {},
          onError: (_) {},
        );

        expect(saver.saved.length, lessThan(8));
        expect(compressor.qualities.length, lessThan(8));
      });
    });

    test('global quality overrides each image quality', () async {
      final compressor = FakeImageCompressor(dir);
      await CompressImagesUseCase(compressor, FakeSaver())(
        images: [makeImage('a.jpg', quality: 10), makeImage('b.jpg', quality: 20)],
        globalQuality: 70,
        isCancelled: () => false,
        onProgress: (_) {},
        onError: (_) {},
      );
      expect(compressor.qualities, [70, 70]);

      final perImage = FakeImageCompressor(dir);
      await CompressImagesUseCase(perImage, FakeSaver())(
        images: [makeImage('c.jpg', quality: 10), makeImage('d.jpg', quality: 20)],
        isCancelled: () => false,
        onProgress: (_) {},
        onError: (_) {},
      );
      expect(perImage.qualities, [10, 20]);
    });
  });
}
