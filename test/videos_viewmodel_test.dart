import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';
import 'package:petit/features/videos/presentation/state/videos_state.dart';
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
