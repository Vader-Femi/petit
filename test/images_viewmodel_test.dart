import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';

import 'helpers/viewmodel_fakes.dart';

void main() {
  late Directory dir;
  late Harness h;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('petit_images_vm_');
    h = Harness(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('picking', () {
    test('loads the images and selects the first', () async {
      h.picker.images = [h.file('a.jpg', 100).path, h.file('b.jpg', 100).path];
      final c = h.container();

      await c.read(imagesViewModelProvider.notifier).pickImages();

      final s = c.read(imagesViewModelProvider);
      expect(s.pickedImages.length, 2);
      expect(s.currentImage, s.pickedImages.first);
      expect(s.currentImageIndex, 0);
      expect(s.pickedImages.first.pixelWidth, 640);
      expect(s.isBusy, isFalse);
    });

    test('picking nothing reports it', () async {
      final c = h.container();

      await c.read(imagesViewModelProvider.notifier).pickImages();

      final s = c.read(imagesViewModelProvider);
      expect(s.result, 'No file picked!');
      expect(s.pickedImages, isEmpty);
      expect(s.isBusy, isFalse);
    });

    test('is ignored while a pick is already running', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      h.picker.gate = Completer<void>();
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);

      final first = vm.pickImages();
      expect(c.read(imagesViewModelProvider).isBusy, isTrue);

      await vm.pickImages(); // ignored
      expect(h.picker.imageCalls, 1);

      h.picker.gate!.complete();
      await first;
      expect(c.read(imagesViewModelProvider).pickedImages.length, 1);
    });

    test('addImagePaths replaces the selection', () async {
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);

      await vm.addImagePaths([h.file('a.jpg', 100).path]);
      await vm.addImagePaths([h.file('b.jpg', 100).path, h.file('c.jpg', 100).path]);

      expect(c.read(imagesViewModelProvider).pickedImages.length, 2);
    });
  });

  group('quality', () {
    test('changing one image replaces it without mutating the old list',
        () async {
      h.picker.images = [h.file('a.jpg', 100).path, h.file('b.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();
      vm.setGlobalQualityEnabled(true);
      final before = c.read(imagesViewModelProvider);

      vm.updateCurrentImageQuality(0.3);

      final after = c.read(imagesViewModelProvider);
      expect(after.pickedImages, isNot(same(before.pickedImages)));
      expect(before.pickedImages.first.quality, 50);
      expect(after.pickedImages.first.quality, 30);
      expect(after.currentImage, after.pickedImages.first);
      expect(after.globalQuality, isNull);
    });

    test('shared quality can be switched on, changed and off', () async {
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);

      vm.setGlobalQualityEnabled(true);
      expect(c.read(imagesViewModelProvider).globalQuality, 50);

      vm.updateGlobalQualitySlider(0.8);
      expect(c.read(imagesViewModelProvider).globalQuality, 80);

      vm.setGlobalQualityEnabled(false);
      expect(c.read(imagesViewModelProvider).globalQuality, isNull);
    });

    test('moving to another image selects it', () async {
      h.picker.images = [h.file('a.jpg', 100).path, h.file('b.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      vm.updateCurrentImageAndIndex(1);
      final s = c.read(imagesViewModelProvider);
      expect(s.currentImageIndex, 1);
      expect(s.currentImage, s.pickedImages[1]);

      vm.updateCurrentImageAndIndex(9); // out of range: ignored
      expect(c.read(imagesViewModelProvider).currentImageIndex, 1);
    });
  });

  group('options and size estimate', () {
    // The estimate waits half a second after the last change.
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 700));

    test('options default to keeping transparency and keeping metadata', () {
      final c = h.container();
      final options = c.read(imagesViewModelProvider).options;
      expect(options.keepTransparency, isTrue);
      expect(options.removeLocation, isFalse);
    });

    test('options reach the compressor when compressing', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();
      vm.setRemoveLocation(true);
      vm.setKeepTransparency(false);

      await vm.compressAllSelectedImages();

      expect(h.imageCompressor.lastOptions?.removeLocation, isTrue);
      expect(h.imageCompressor.lastOptions?.keepTransparency, isFalse);
    });

    test('estimates the current image after picking', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container();
      await c.read(imagesViewModelProvider.notifier).pickImages();
      expect(c.read(imagesViewModelProvider).isEstimating, isTrue);

      await settle();

      final s = c.read(imagesViewModelProvider);
      expect(s.isEstimating, isFalse);
      expect(s.estimate?.originalBytes, 100);
      expect(s.estimate?.estimatedBytes, 40);
    });

    test('a new setting clears the old estimate and estimates again',
        () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();
      await settle();
      expect(c.read(imagesViewModelProvider).estimate, isNotNull);

      vm.updateCurrentImageQuality(0.8);
      final during = c.read(imagesViewModelProvider);
      expect(during.estimate, isNull);
      expect(during.isEstimating, isTrue);

      await settle();
      expect(c.read(imagesViewModelProvider).estimate, isNotNull);
    });

    test('clearing the images drops the estimate', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();
      await settle();

      vm.clearPickedImages();

      final s = c.read(imagesViewModelProvider);
      expect(s.estimate, isNull);
      expect(s.isEstimating, isFalse);
    });

    test('does not start compressing while a video is loading', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container();
      final images = c.read(imagesViewModelProvider.notifier);
      await images.pickImages();

      h.picker.video = h.file('in.mp4', 100).path;
      h.picker.gate = Completer<void>();
      final loadingVideo =
          c.read(videosViewModelProvider.notifier).pickVideo();

      final report = await images.compressAllSelectedImages();

      expect(report, isNull);
      expect(c.read(imagesViewModelProvider).result,
          'Wait for the video to finish first');
      h.picker.gate!.complete();
      await loadingVideo;
    });
  });

  group('background', () {
    test('keeps the app alive while compressing, and lets go afterwards',
        () async {
      h.picker.images = [h.file('a.jpg', 100).path, h.file('b.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      await vm.compressAllSelectedImages();

      final calls = h.keepAlive.calls;
      expect(calls.first, 'permission');
      expect(calls[1], 'start:Compressing images');
      expect(calls.any((call) => call.startsWith('update:')), isTrue);
      expect(calls.last, 'stop');
    });

    test('lets go when saving is declined', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      h.saver.declineToPrepare = true;
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      final report = await vm.compressAllSelectedImages();

      expect(report, isNull);
      expect(h.keepAlive.calls.last, 'stop');
    });

    test('a broken keep-alive does not stop the compression', () async {
      h.keepAlive.failWith = StateError('no service');
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      final report = await vm.compressAllSelectedImages();

      expect(report, isNotNull);
    });

    test('names the image being worked on', () async {
      h.picker.images = [h.file('a.jpg', 100).path, h.file('b.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      await vm.compressAllSelectedImages();

      expect(h.keepAlive.calls, contains('update:0:Image 1 of 2'));
    });
  });

  group('clearing', () {
    test('clearPickedImages empties the selection', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      vm.clearPickedImages();

      final s = c.read(imagesViewModelProvider);
      expect(s.pickedImages, isEmpty);
      expect(s.currentImage, isNull);
      expect(s.globalQuality, isNull);
      expect(s.isBusy, isFalse);
    });

    test('messages can be cleared once shown', () {
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);

      vm.showResult('Hello');
      expect(c.read(imagesViewModelProvider).result, 'Hello');

      vm.clearResult();
      expect(c.read(imagesViewModelProvider).result, isNull);
    });

    test('the actions menu can be toggled', () {
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);

      expect(c.read(imagesViewModelProvider).isFabOpen, isTrue);
      vm.toggleFab();
      expect(c.read(imagesViewModelProvider).isFabOpen, isFalse);
    });
  });

  group('compressing', () {
    test('returns a summary, saves, and cleans up', () async {
      h.picker.images = [h.file('a.jpg', 100).path, h.file('b.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      final report = await vm.compressAllSelectedImages();

      expect(report, isNotNull);
      expect(report!.originalSizeBytes, '200.00 B');
      expect(report.compressedSizeBytes, '80.00 B');
      expect(report.savedBytes, '120.00 B');
      expect(report.savedPercent, closeTo(0.6, 1e-9));
      expect(report.path, 'Photos');
      expect(h.saver.saved.length, 2);
      expect(h.workspace.clears, 1);

      final s = c.read(imagesViewModelProvider);
      expect(s.pickedImages, isEmpty);
      expect(s.isBusy, isFalse);
      expect(s.loading.progressCounter, 100);
    });

    test('the summary carries the folder to open, when there is one', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      h.saver.folder = '/saved/here';
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      final report = await vm.compressAllSelectedImages();

      expect(report!.folderPath, '/saved/here');
    });

    test('startCompression delivers the summary to onComplete', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      final done = Completer<SummaryReport>();
      vm.startCompression(onComplete: done.complete);

      final report = await done.future;
      expect(report.path, 'Photos');
    });

    test('with nothing selected it says so', () async {
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);

      expect(await vm.compressAllSelectedImages(), isNull);
      expect(c.read(imagesViewModelProvider).result, 'Select images first');
    });

    test('declining the destination keeps the selection', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      h.saver.declineToPrepare = true;
      final c = h.container();
      final vm = c.read(imagesViewModelProvider.notifier);
      await vm.pickImages();

      expect(await vm.compressAllSelectedImages(), isNull);

      final s = c.read(imagesViewModelProvider);
      expect(s.result, 'No output folder selected.');
      expect(s.pickedImages.length, 1);
      expect(s.isBusy, isFalse);
    });
  });
}
