import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/home/presentation/state/home_viewmodel.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';

import 'helpers/viewmodel_fakes.dart';

void main() {
  late Directory dir;
  late Harness h;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('petit_home_vm_');
    h = Harness(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('starts on the Images tab', () {
    final c = h.container();
    expect(c.read(homeViewModelProvider), 0);
  });

  test('switching to Videos keeps the picked images', () async {
    h.picker.images = [h.file('a.jpg', 100).path];
    final c = h.container();
    await c.read(imagesViewModelProvider.notifier).pickImages();

    await c.read(homeViewModelProvider.notifier).updateCurrentTabIndex(1);

    expect(c.read(homeViewModelProvider), 1);
    expect(c.read(imagesViewModelProvider).pickedImages.length, 1);
  });

  test('switching to Images keeps the video', () async {
    h.picker.video = h.file('in.mp4', 100).path;
    final c = h.container();
    await c.read(videosViewModelProvider.notifier).pickVideo();

    await c.read(homeViewModelProvider.notifier).updateCurrentTabIndex(0);

    expect(c.read(homeViewModelProvider), 0);
    expect(c.read(videosViewModelProvider).videoFile, isNotNull);
    expect(h.previews.single.disposed, isFalse);
  });

  test('a tab keeps its settings when you leave and come back', () async {
    h.picker.images = [h.file('a.jpg', 100).path];
    final c = h.container();
    final images = c.read(imagesViewModelProvider.notifier);
    await images.pickImages();
    images.setRemoveLocation(true);
    images.updateCurrentImageQuality(0.8);
    final home = c.read(homeViewModelProvider.notifier);

    await home.updateCurrentTabIndex(1);
    await home.updateCurrentTabIndex(0);

    final s = c.read(imagesViewModelProvider);
    expect(s.options.removeLocation, isTrue);
    expect(s.currentImage?.quality, 80);
  });

  test('leaving the Videos tab pauses the video', () async {
    h.picker.video = h.file('in.mp4', 100).path;
    final c = h.container();
    await c.read(videosViewModelProvider.notifier).pickVideo();
    h.previews.single.playing = true;

    await c.read(homeViewModelProvider.notifier).updateCurrentTabIndex(0);

    expect(h.previews.single.playing, isFalse);
  });

  test('is busy while either tab is working', () async {
    final c = h.container();
    final home = c.read(homeViewModelProvider.notifier);
    expect(home.isBusy, isFalse);

    // Images tab busy
    h.picker.images = [h.file('a.jpg', 100).path];
    h.picker.gate = Completer<void>();
    final pickingImages = c.read(imagesViewModelProvider.notifier).pickImages();
    expect(home.isBusy, isTrue);
    h.picker.gate!.complete();
    await pickingImages;
    expect(home.isBusy, isFalse);

    // Videos tab busy
    h.picker.video = h.file('in.mp4', 100).path;
    h.picker.gate = Completer<void>();
    final pickingVideo = c.read(videosViewModelProvider.notifier).pickVideo();
    expect(home.isBusy, isTrue);
    h.picker.gate!.complete();
    await pickingVideo;
    expect(home.isBusy, isFalse);
  });
}
