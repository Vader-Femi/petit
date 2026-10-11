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

  test('switching to Videos clears the picked images', () async {
    h.picker.images = [h.file('a.jpg', 100).path];
    final c = h.container();
    await c.read(imagesViewModelProvider.notifier).pickImages();

    await c.read(homeViewModelProvider.notifier).updateCurrentTabIndex(1);

    expect(c.read(homeViewModelProvider), 1);
    expect(c.read(imagesViewModelProvider).pickedImages, isEmpty);
  });

  test('switching to Images removes the video', () async {
    h.picker.video = h.file('in.mp4', 100).path;
    final c = h.container();
    await c.read(videosViewModelProvider.notifier).pickVideo();

    await c.read(homeViewModelProvider.notifier).updateCurrentTabIndex(0);

    expect(c.read(homeViewModelProvider), 0);
    expect(c.read(videosViewModelProvider).videoFile, isNull);
    expect(h.previews.single.disposed, isTrue);
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
