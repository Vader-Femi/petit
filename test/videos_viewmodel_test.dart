import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/settings/domain/entities/app_settings.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';
import 'package:petit/features/videos/presentation/state/videos_state.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';

import 'helpers/viewmodel_fakes.dart';

/// Polls until [condition] holds, failing the test if it never does.
Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting.');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late Directory dir;
  late Harness h;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('petit_videos_vm_');
    h = Harness(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  // A sparse file: big on paper, instant to create.
  File sparseFile(String name, int bytes) {
    final file = File('${dir.path}/$name');
    final handle = file.openSync(mode: FileMode.write);
    handle.setPositionSync(bytes - 1);
    handle.writeByteSync(0);
    handle.closeSync();
    return file;
  }

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

  group('video information', () {
    test('the video is probed and its size read when it is picked', () async {
      h.picker.video = h.file('in.mp4', 1000).path;
      final c = h.container();

      await c.read(videosViewModelProvider.notifier).pickVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.videoInfo?.pixelHeight, 1080);
      expect(s.videoBytes, 1000);
      expect(s.sourceShortSide, 1080);
    });

    test('removing the video forgets what was read from it', () async {
      h.picker.video = h.file('in.mp4', 1000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();

      vm.removeVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.videoInfo, isNull);
      expect(s.videoBytes, isNull);
    });

    test('a resolution that would not shrink the video is not offered', () async {
      h.picker.video = h.file('in.mp4', 1000).path;
      final c = h.container();
      await c.read(videosViewModelProvider.notifier).pickVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.canUseResolution(VideoResolution.original), isTrue);
      expect(s.canUseResolution(VideoResolution.p720), isTrue);
      expect(s.canUseResolution(VideoResolution.p1080), isFalse); // 1080 is its size
    });

    test('a choice that no longer fits the next video is moved to one that does',
        () async {
      h.picker.video = sparseFile('big.mp4', 60000000).path; // 60 MB
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      vm.setResolution(VideoResolution.p1080); // the video is 1080p: no shrink
      vm.setTargetSizeMb(100); // bigger than the file

      await vm.pickVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.resolution, VideoResolution.original);
      expect(s.targetSizeMb, 50, reason: 'the largest size below 60 MB');
      expect(s.canTargetMb(50), isTrue);
      expect(s.canTargetMb(100), isFalse);
    });

    test('choices that fit are kept', () async {
      h.picker.video = sparseFile('big.mp4', 60000000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      vm.setResolution(VideoResolution.p720);
      vm.setTargetSizeMb(10);

      await vm.pickVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.resolution, VideoResolution.p720);
      expect(s.targetSizeMb, 10);
    });
  });

  group('fast encoding', () {
    Future<(ProviderContainer, VideosViewModel)> pick({
      String? hardware,
      AppSettings settings = const AppSettings(),
    }) async {
      h.videoCompressor.hardwareEncoder = hardware;
      h.picker.video = h.file('in.mp4', 1000).path;
      final c = h.container(settings: settings);
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      await pumpEventQueue(); // the hardware check runs in the background
      return (c, vm);
    }

    test('is offered when the machine has hardware for the video', () async {
      final (c, _) = await pick(hardware: 'h264_nvenc');

      expect(c.read(videosViewModelProvider).fastEncodingAvailable, isTrue);
      expect(h.videoCompressor.hardwareChecks, 1);
    });

    test('is not offered when it has none', () async {
      final (c, _) = await pick();

      expect(c.read(videosViewModelProvider).fastEncodingAvailable, isFalse);
    });

    test('choosing it counts only when it is available', () async {
      final (c, vm) = await pick();
      vm.setFastEncoding(true);

      final s = c.read(videosViewModelProvider);
      expect(s.fastEncoding, isTrue);
      expect(s.usesFastEncoding, isFalse);
    });

    test('compressing uses the hardware when chosen and available', () async {
      final (_, vm) = await pick(hardware: 'h264_nvenc');
      vm.setFastEncoding(true);

      await vm.compressVideo(onComplete: (_) {});

      expect(h.videoCompressor.usedHardwareEncoder, 'h264_nvenc');
      expect(h.videoCompressor.usedHardwareBitrateKbps, isNotNull);
    });

    test('compressing uses normal encoding when not chosen', () async {
      final (_, vm) = await pick(hardware: 'h264_nvenc');

      await vm.compressVideo(onComplete: (_) {});

      expect(h.videoCompressor.usedHardwareEncoder, isNull);
    });

    test('compressing falls back quietly when it is chosen but not available',
        () async {
      final (_, vm) = await pick();
      vm.setFastEncoding(true);

      await vm.compressVideo(onComplete: (_) {});

      expect(h.videoCompressor.usedHardwareEncoder, isNull);
      expect(h.videoCompressor.lastTask, isNotNull);
    });

    test('starts from the default in Settings', () async {
      final (c, _) = await pick(
          hardware: 'h264_nvenc',
          settings: const AppSettings(videoFastEncoding: true));

      expect(c.read(videosViewModelProvider).usesFastEncoding, isTrue);
    });

    test('removing the video forgets that hardware was found', () async {
      final (c, vm) = await pick(hardware: 'h264_nvenc');

      vm.removeVideo();

      expect(c.read(videosViewModelProvider).fastEncodingAvailable, isFalse);
    });

    test('a late answer for a video that is gone is ignored', () async {
      h.videoCompressor.hardwareEncoder = 'h264_nvenc';
      h.picker.video = h.file('in.mp4', 1000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);

      await vm.pickVideo();
      vm.removeVideo(); // before the background check answered
      await pumpEventQueue();

      expect(c.read(videosViewModelProvider).fastEncodingAvailable, isFalse);
    });
  });

  group('size estimate', () {
    Future<(ProviderContainer, VideosViewModel)> pick({int bytes = 1000}) async {
      h.picker.video = h.file('in.mp4', bytes).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      return (c, vm);
    }

    Future<void> settled(ProviderContainer c) =>
        waitUntil(() => !c.read(videosViewModelProvider).isEstimating);

    test('a short video is compressed whole and the size is exact', () async {
      final (c, vm) = await pick();

      await vm.estimateSize();

      final s = c.read(videosViewModelProvider);
      expect(s.isEstimating, isFalse);
      expect(h.videoCompressor.samples, [(0, 5000)]);
      expect(s.currentEstimate?.originalBytes, 1000);
      expect(s.currentEstimate?.estimatedBytes, 500); // 100 B/s for 5 s
      expect(s.currentEstimate?.isExact, isTrue);
    });

    test('a long video is sampled in three places', () async {
      h.videoCompressor.probeDurationMs = 60000;
      final (c, vm) = await pick();

      await vm.estimateSize();

      expect(h.videoCompressor.samples,
          [(9000, 2000), (29000, 2000), (49000, 2000)]);
      // 600 bytes over 6 s, for 60 s.
      expect(c.read(videosViewModelProvider).currentEstimate?.estimatedBytes,
          6000);
    });

    test('it is shown only while the choices are the same', () async {
      final (c, vm) = await pick();
      await vm.estimateSize();
      expect(c.read(videosViewModelProvider).currentEstimate, isNotNull);

      vm.updateCfrQualitySlider(0.25);

      final s = c.read(videosViewModelProvider);
      expect(s.currentEstimate, isNull, reason: 'the choices changed');
      expect(s.estimate, isNotNull, reason: 'kept, but stale');
    });

    test('a changed resolution, mode or fast encoding makes it stale', () async {
      final (c, vm) = await pick();
      await vm.estimateSize();

      vm.setResolution(VideoResolution.p720);
      expect(c.read(videosViewModelProvider).currentEstimate, isNull);

      await vm.estimateSize();
      expect(c.read(videosViewModelProvider).currentEstimate, isNotNull);

      vm.setMode(VideoMode.targetSize);
      expect(c.read(videosViewModelProvider).currentEstimate, isNull);
    });

    test('estimating again after a change works', () async {
      final (c, vm) = await pick();
      await vm.estimateSize();
      vm.setResolution(VideoResolution.p720);

      await vm.estimateSize();

      expect(c.read(videosViewModelProvider).currentEstimate, isNotNull);
      expect(h.videoCompressor.usedMaxShortSide, 720);
    });

    test('uses the video hardware for the samples when chosen', () async {
      h.videoCompressor.hardwareEncoder = 'h264_nvenc';
      final (c, vm) = await pick();
      await pumpEventQueue();
      vm.setFastEncoding(true);

      await vm.estimateSize();

      expect(h.videoCompressor.usedHardwareEncoder, 'h264_nvenc');
      expect(c.read(videosViewModelProvider).currentEstimate, isNotNull);
    });

    test('is refused with a target that cannot help', () async {
      h.picker.video = sparseFile('big.mp4', 60000000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      vm.setMode(VideoMode.targetSize);
      vm.setTargetSizeMb(100);

      await vm.estimateSize();

      expect(c.read(videosViewModelProvider).result, contains('not smaller'));
      expect(h.videoCompressor.samples, isEmpty);
    });

    test('is refused while images are being compressed', () async {
      final (c, vm) = await pick();
      h.picker.images = [h.file('a.jpg', 100).path];
      h.picker.gate = Completer<void>();
      final loading = c.read(imagesViewModelProvider.notifier).pickImages();

      await vm.estimateSize();

      expect(c.read(videosViewModelProvider).result,
          'Wait for the images to finish first');
      expect(h.videoCompressor.samples, isEmpty);
      h.picker.gate!.complete();
      await loading;
    });

    test('a video whose length is unknown reports it', () async {
      h.videoCompressor.probeDurationMs = null;
      final (c, vm) = await pick();

      await vm.estimateSize();

      final s = c.read(videosViewModelProvider);
      expect(s.result, contains('cannot be estimated'));
      expect(s.isEstimating, isFalse);
      expect(s.estimate, isNull);
    });

    group('cancelling', () {
      test('stops the estimate quietly', () async {
        h.videoCompressor.holdSamples = true;
        final (c, vm) = await pick();

        final running = vm.estimateSize();
        await waitUntil(() => h.videoCompressor.samples.isNotEmpty);
        expect(c.read(videosViewModelProvider).isEstimating, isTrue);

        vm.cancelEstimate();
        await running;

        final s = c.read(videosViewModelProvider);
        expect(s.isEstimating, isFalse);
        expect(s.estimate, isNull);
        expect(s.result, isNull, reason: 'cancelling is not an error');
        expect(h.videoCompressor.lastSampleTask?.cancelled, isTrue);
      });

      test('removing the video cancels it too', () async {
        h.videoCompressor.holdSamples = true;
        final (c, vm) = await pick();
        final running = vm.estimateSize();
        await waitUntil(() => h.videoCompressor.samples.isNotEmpty);

        vm.removeVideo();
        await running;

        final s = c.read(videosViewModelProvider);
        expect(s.isEstimating, isFalse);
        expect(s.estimate, isNull);
        expect(s.result, isNull);
      });

      test('starting to compress cancels it', () async {
        h.videoCompressor.holdSamples = true;
        final (c, vm) = await pick();
        final running = vm.estimateSize();
        await waitUntil(() => h.videoCompressor.samples.isNotEmpty);

        await vm.compressVideo(onComplete: (_) {});
        await running;

        expect(c.read(videosViewModelProvider).isEstimating, isFalse);
        expect(h.videoCompressor.lastSampleTask?.cancelled, isTrue);
        expect(h.videoCompressor.lastTask, isNotNull,
            reason: 'the real job still starts');
      });

      test('an old estimate cannot overwrite a newer one', () async {
        h.videoCompressor.holdSamples = true;
        final (c, vm) = await pick();
        final first = vm.estimateSize();
        await waitUntil(() => h.videoCompressor.samples.length == 1);
        vm.cancelEstimate();
        await first;

        h.videoCompressor.holdSamples = false;
        await vm.estimateSize();

        expect(c.read(videosViewModelProvider).currentEstimate, isNotNull);
        expect(c.read(videosViewModelProvider).result, isNull);
      });
    });

    test('while it runs, compressing and a second estimate are not started',
        () async {
      h.videoCompressor.holdSamples = true;
      final (c, vm) = await pick();
      final running = vm.estimateSize();
      await waitUntil(() => h.videoCompressor.samples.isNotEmpty);

      await vm.estimateSize(); // ignored: one is already running

      expect(h.videoCompressor.samples.length, 1);
      vm.cancelEstimate();
      await running;
      await settled(c);
    });
  });

  group('progress', () {
    test('reports percent, and has no time left this early', () async {
      h.picker.video = h.file('in.mp4', 1000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      await vm.compressVideo(onComplete: (_) {});

      h.videoCompressor.progressCallback!(40);

      final s = c.read(videosViewModelProvider);
      expect(s.percentComplete, 40);
      expect(s.eta, isNull, reason: 'a fraction of a second is too early');
    });

    test('removing the video clears the time left', () async {
      h.picker.video = h.file('in.mp4', 1000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();

      vm.removeVideo();

      expect(c.read(videosViewModelProvider).eta, isNull);
      expect(c.read(videosViewModelProvider).percentComplete, 0);
    });
  });

  group('custom target size and warnings', () {
    test('a typed size is kept, within limits', () {
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);

      vm.setTargetSizeMb(37);
      expect(c.read(videosViewModelProvider).targetSizeMb, 37);

      vm.setTargetSizeMb(0);
      expect(c.read(videosViewModelProvider).targetSizeMb, 1);

      vm.setTargetSizeMb(99999);
      expect(c.read(videosViewModelProvider).targetSizeMb, kMaxTargetSizeMb);
    });

    test('a video smaller than the smallest preset gets a size that fits',
        () async {
      h.picker.video = sparseFile('small.mp4', 4000000).path; // 4 MB
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);

      await vm.pickVideo();

      final s = c.read(videosViewModelProvider);
      expect(s.targetSizeMb, 2, reason: 'half of 4 MB');
      expect(s.canTargetMb(s.targetSizeMb), isTrue);
    });

    test('there are no warnings before a video is picked', () {
      final c = h.container();
      expect(c.read(videosViewModelProvider).warnings, isEmpty);
    });

    test('a target that is not smaller than the video is flagged', () async {
      h.picker.video = sparseFile('big.mp4', 60000000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      vm.setMode(VideoMode.targetSize);

      vm.setTargetSizeMb(50);
      expect(c.read(videosViewModelProvider).warnings, isEmpty);

      vm.setTargetSizeMb(60);
      final warnings = c.read(videosViewModelProvider).warnings;
      expect(warnings.single.blocksStart, isTrue);
    });

    test('compressing does not start with a target that cannot help',
        () async {
      h.picker.video = sparseFile('big.mp4', 60000000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      vm.setMode(VideoMode.targetSize);
      vm.setTargetSizeMb(100);

      await vm.compressVideo(onComplete: (_) {});

      final s = c.read(videosViewModelProvider);
      expect(s.isCompressing, isFalse);
      expect(s.result, contains('not smaller'));
      expect(h.videoCompressor.lastTask, isNull);
    });

    test('a warning that only advises does not stop compressing', () async {
      h.picker.video = sparseFile('big.mp4', 60000000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      vm.updateCfrQualitySlider(0); // Minimal compression

      expect(c.read(videosViewModelProvider).warnings, hasLength(1));
      await vm.compressVideo(onComplete: (_) {});

      expect(h.videoCompressor.lastTask, isNotNull);
    });
  });

  group('options reach the compressor', () {
    test('quality mode with a resolution', () async {
      h.picker.video = h.file('in.mp4', 1000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      vm.setResolution(VideoResolution.p720);

      await vm.compressVideo(onComplete: (_) {});

      expect(h.videoCompressor.usedMaxShortSide, 720);
      expect(h.videoCompressor.usedBitrateKbps, isNull);
    });

    test('target size mode asks for a bitrate that fits the length', () async {
      h.picker.video = sparseFile('big.mp4', 60000000).path; // 60 MB
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      vm.setMode(VideoMode.targetSize);
      vm.setTargetSizeMb(10);

      await vm.compressVideo(onComplete: (_) {});

      // The fake video lasts 5 seconds.
      expect(
        h.videoCompressor.usedBitrateKbps,
        bitrateForTargetSize(targetBytes: 10000000, durationMs: 5000),
      );
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
      vm.setMode(VideoMode.targetSize);
      vm.setResolution(VideoResolution.p480);
      vm.setTargetSizeMb(50);

      final s = c.read(videosViewModelProvider);
      expect(s.crfQuality, 40);
      expect(s.presetIndex, 2);
      expect(s.mode, VideoMode.targetSize);
      expect(s.resolution, VideoResolution.p480);
      expect(s.targetSizeMb, 50);
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

    test('keeps the app alive while compressing, and lets go afterwards',
        () async {
      final (_, vm) = await start();
      final done = Completer<SummaryReport>();

      await vm.compressVideo(onComplete: done.complete);
      expect(h.keepAlive.calls, ['permission', 'start:Compressing video']);

      h.videoCompressor.progressCallback!(42);
      expect(h.keepAlive.calls.last, 'update:42:42% done');

      h.videoCompressor.lastTask!.completer.complete(h.file('out.mp4', 400));
      await done.future;
      expect(h.keepAlive.calls.last, 'stop');
    });

    test('lets go when the compression fails', () async {
      final (_, vm) = await start();

      await vm.compressVideo(onComplete: (_) {});
      h.videoCompressor.lastTask!.completer
          .completeError(const MediaException('Compression failed.'));
      await pumpEventQueue();

      expect(h.keepAlive.calls.last, 'stop');
    });

    test('a broken keep-alive does not stop the compression', () async {
      h.keepAlive.failWith = StateError('no service');
      final (c, vm) = await start();
      final done = Completer<SummaryReport>();

      await vm.compressVideo(onComplete: done.complete);
      h.videoCompressor.lastTask!.completer.complete(h.file('out.mp4', 400));

      await done.future;
      expect(c.read(videosViewModelProvider).result, isNull);
    });

    test('does not ask for the keep-alive when compressing is refused',
        () async {
      h.picker.video = sparseFile('big.mp4', 60000000).path;
      final c = h.container();
      final vm = c.read(videosViewModelProvider.notifier);
      await vm.pickVideo();
      vm.setMode(VideoMode.targetSize);
      vm.setTargetSizeMb(100);

      await vm.compressVideo(onComplete: (_) {});

      expect(h.keepAlive.calls, isEmpty);
    });

    test('the summary carries the folder to open, when there is one', () async {
      h.saver.folder = '/saved/here';
      final (c, vm) = await start();
      final done = Completer<SummaryReport>();

      await vm.compressVideo(onComplete: done.complete);
      h.videoCompressor.lastTask!.completer.complete(h.file('out.mp4', 400));

      expect((await done.future).folderPath, '/saved/here');
      expect(c.read(videosViewModelProvider).videoFile, isNull);
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
