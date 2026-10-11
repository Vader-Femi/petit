import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';

import 'helpers/viewmodel_fakes.dart';

void main() {
  late Directory dir;
  late Harness h;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('petit_videos_vm_');
    h = Harness(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('loading a video', () {
    test('shows the preview and keeps the file', () async {
      final input = h.file('in.mp4', 1000);
      h.picker.video = input.path;
      final c = h.container();

      await c.read(videosViewModelProvider.notifier).pickVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.videoFile?.path, input.path);
      expect(s.preview, isNotNull);
      expect(s.preview!.isInitialized, isTrue);
      expect(s.isLoading, isFalse);
    });

    test('picking nothing reports it', () async {
      final c = h.container();

      await c.read(videosViewModelProvider.notifier).pickVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.result, 'No file picked!');
      expect(s.videoFile, isNull);
      expect(s.isLoading, isFalse);
    });

    test('a preview that cannot start reports an error', () async {
      h.picker.video = h.file('in.mp4', 10).path;
      h.previewInitializeError = const MediaException('bad video');
      final c = h.container();

      await c.read(videosViewModelProvider.notifier).pickVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.result, startsWith('An error occurred'));
      expect(s.videoFile, isNull);
      expect(s.isLoading, isFalse);
    });

    test('addVideoPath loads a dropped video', () async {
      final input = h.file('dropped.mp4', 10);
      final c = h.container();

      await c.read(videosViewModelProvider.notifier).addVideoPath(input.path);

      expect(c.read(videosViewModelProvider).videoFile?.path, input.path);
    });

    test('removeVideo disposes the preview and resets', () async {
      h.picker.video = h.file('in.mp4', 10).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();

      vm.removeVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.videoFile, isNull);
      expect(s.preview, isNull);
      expect(s.isBusy, isFalse);
      expect(h.previews.single.disposed, isTrue);
    });
  });

  group('settings', () {
    test('sliders update the state', () {
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);

      expect(c.read(videosViewModelProvider).crfQuality, 80);
      expect(c.read(videosViewModelProvider).presetIndex, 1);

      vm.updateCfrQualitySlider(0.4);
      vm.setPresetIndex(2);

      final s = c.read(videosViewModelProvider);
      expect(s.crfQuality, 40);
      expect(s.presetIndex, 2);
    });
  });

  group('compressing', () {
    Future<(ProviderContainer, VideosViewModel)> start() async {
      h.picker.video = h.file('in.mp4', 1000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      return (c, vm);
    }

    test('runs, reports progress, and delivers a summary', () async {
      final (c, vm) = await start();
      final done = Completer<SummaryReport>();

      await vm.compressVideo(onComplete: done.complete);

      var s = c.read(videosViewModelProvider);
      expect(s.isCompressing, isTrue);
      expect(s.currentJob, isNotNull);

      h.videoCompressor.progressCallback!(42);
      expect(c.read(videosViewModelProvider).percentComplete, 42);

      h.videoCompressor.lastTask!.completer.complete(h.file('out.mp4', 400));
      final report = await done.future;

      expect(report.originalSizeBytes, formatBytes(1000));
      expect(report.compressedSizeBytes, formatBytes(400));
      expect(report.savedBytes, formatBytes(600));
      expect(report.path, 'Movies/Petit');

      s = c.read(videosViewModelProvider);
      expect(s.videoFile, isNull);
      expect(s.isCompressing, isFalse);
      expect(s.currentJob, isNull);
      expect(h.workspace.clears, 1);
      expect(h.previews.single.disposed, isTrue);
    });

    test('a failed compression reports it and resets', () async {
      final (c, vm) = await start();

      await vm.compressVideo(onComplete: (_) => fail('should not complete'));
      h.videoCompressor.lastTask!.completer
          .completeError(const MediaException('Compression failed.'));
      await pumpEventQueue();

      final s = c.read(videosViewModelProvider);
      expect(s.result, 'Compression failed.');
      expect(s.isCompressing, isFalse);
      expect(s.currentJob, isNull);
    });

    test('cancelling stops the task and resets', () async {
      final (c, vm) = await start();
      await vm.compressVideo(onComplete: (_) {});

      vm.cancelCompressingVideo();

      expect(h.videoCompressor.lastTask!.cancelled, isTrue);
      final s = c.read(videosViewModelProvider);
      expect(s.currentJob, isNull);
      expect(s.isCompressing, isFalse);
      expect(s.isLoading, isFalse);
    });

    test('declining the destination does not start', () async {
      final (c, vm) = await start();
      h.saver.declineToPrepare = true;

      await vm.compressVideo(onComplete: (_) => fail('should not complete'));

      final s = c.read(videosViewModelProvider);
      expect(s.result, 'No output folder selected.');
      expect(s.isCompressing, isFalse);
      expect(s.currentJob, isNull);
      expect(h.videoCompressor.lastTask, isNull);
    });

    test('with no video it does nothing', () async {
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);

      await vm.compressVideo(onComplete: (_) => fail('should not complete'));

      expect(c.read(videosViewModelProvider).isCompressing, isFalse);
    });
  });
}
