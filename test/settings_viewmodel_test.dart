import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:petit/features/settings/domain/entities/app_settings.dart';
import 'package:petit/features/settings/presentation/state/settings_viewmodel.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/videos/presentation/state/videos_state.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';

import 'helpers/viewmodel_fakes.dart';

void main() {
  late Directory dir;
  late Harness h;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('petit_settings_vm_');
    h = Harness(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('settings', () {
    test('start from what was loaded at launch', () {
      final c = h.container(settings: const AppSettings(imageQuality: 70));
      expect(c.read(settingsViewModelProvider).imageQuality, 70);
    });

    test('every change is applied and saved', () {
      final c = h.container();
      final vm = c.read(settingsViewModelProvider.notifier);

      vm.setImageQuality(30);
      vm.setKeepTransparency(false);
      vm.setRemoveLocation(true);
      vm.setVideoUseTargetSize(true);
      vm.setVideoQuality(60);
      vm.setVideoResolution(VideoResolution.p720);
      vm.setVideoPresetIndex(2);
      vm.setVideoTargetSizeMb(10);

      const expected = AppSettings(
        imageQuality: 30,
        keepTransparency: false,
        removeLocation: true,
        videoUseTargetSize: true,
        videoQuality: 60,
        videoResolution: VideoResolution.p720,
        videoPresetIndex: 2,
        videoTargetSizeMb: 10,
      );
      expect(c.read(settingsViewModelProvider), expected);
      expect(h.settingsRepository.saved, expected);
    });

    test('values are kept in range', () {
      final c = h.container();
      final vm = c.read(settingsViewModelProvider.notifier);

      vm.setImageQuality(250);
      vm.setVideoQuality(-5);
      vm.setVideoPresetIndex(9);
      vm.setVideoTargetSizeMb(0);

      final s = c.read(settingsViewModelProvider);
      expect(s.videoTargetSizeMb, 1);
      expect(s.imageQuality, 100);
      expect(s.videoQuality, 0);
      expect(s.videoPresetIndex, AppSettings.maxVideoPresetIndex);
    });

    test('setting the same value saves nothing', () {
      final c = h.container();
      c.read(settingsViewModelProvider.notifier).setImageQuality(50);
      expect(h.settingsRepository.saves, 0);
    });

    test('reset goes back to the defaults', () {
      final c = h.container(settings: const AppSettings(imageQuality: 10));
      c.read(settingsViewModelProvider.notifier).resetToDefaults();

      expect(c.read(settingsViewModelProvider), const AppSettings());
      expect(h.settingsRepository.saved, const AppSettings());
    });

    test('a failed save still applies the change', () async {
      h.settingsRepository.failToSave = true;
      final c = h.container();

      c.read(settingsViewModelProvider.notifier).setImageQuality(20);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(settingsViewModelProvider).imageQuality, 20);
    });
  });

  group('images use the defaults', () {
    test('a new selection starts at the default quality and options',
        () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container(
          settings: const AppSettings(imageQuality: 70, removeLocation: true));

      await c.read(imagesViewModelProvider.notifier).pickImages();

      final s = c.read(imagesViewModelProvider);
      expect(s.currentImage?.quality, 70);
      expect(s.options.removeLocation, isTrue);
    });

    test('changing a default applies while nothing is picked', () async {
      final c = h.container();
      c.read(imagesViewModelProvider); // start it listening

      c.read(settingsViewModelProvider.notifier).setRemoveLocation(true);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(imagesViewModelProvider).options.removeLocation, isTrue);
    });

    test('changing a default leaves a selection in progress alone', () async {
      h.picker.images = [h.file('a.jpg', 100).path];
      final c = h.container();
      await c.read(imagesViewModelProvider.notifier).pickImages();

      c.read(settingsViewModelProvider.notifier).setRemoveLocation(true);

      expect(c.read(imagesViewModelProvider).options.removeLocation, isFalse);
    });
  });

  group('videos use the defaults', () {
    test('start from the saved defaults', () {
      final c = h.container(
          settings: const AppSettings(
        videoUseTargetSize: true,
        videoQuality: 40,
        videoResolution: VideoResolution.p480,
        videoPresetIndex: 0,
        videoTargetSizeMb: 10,
      ));

      final s = c.read(videosViewModelProvider);
      expect(s.mode, VideoMode.targetSize);
      expect(s.crfQuality, 40);
      expect(s.resolution, VideoResolution.p480);
      expect(s.presetIndex, 0);
      expect(s.targetSizeMb, 10);
    });

    test('changing a default applies while no video is picked', () async {
      final c = h.container();
      c.read(videosViewModelProvider); // start it listening

      c.read(settingsViewModelProvider.notifier).setVideoQuality(30);
      await Future<void>.delayed(Duration.zero);

      expect(c.read(videosViewModelProvider).crfQuality, 30);
    });

    test('changing a default leaves a picked video alone', () async {
      h.picker.video = h.file('in.mp4', 100).path;
      final c = h.container();
      await c.read(videosViewModelProvider.notifier).pickVideo();

      c.read(settingsViewModelProvider.notifier).setVideoQuality(30);

      expect(c.read(videosViewModelProvider).crfQuality, 80);
    });
  });
}
