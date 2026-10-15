import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/features/videos/domain/entities/codec_config.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';

class FakeTask implements VideoCompressionTask {
  final completer = Completer<File>();
  bool cancelled = false;

  @override
  Future<File> get result => completer.future;

  @override
  Future<void> cancel() async {
    cancelled = true;
  }
}

class FakeVideoCompressor implements VideoCompressor {
  FakeVideoCompressor({this.data, this.probeFails = false});

  final VideoData? data;
  final bool probeFails;
  final task = FakeTask();
  String? usedCodec;
  int? usedCrf;
  String? usedPreset;
  int? usedDurationMs;
  int? usedBitrateKbps;
  int? usedMaxShortSide;
  String? usedHardwareEncoder;
  int? usedHardwareBitrateKbps;

  /// The hardware encoder this "machine" has, or null for none.
  String? hardwareEncoder;
  final hardwareAskedFor = <String>[];

  @override
  Future<String?> hardwareEncoderFor(String videoCodec) async {
    hardwareAskedFor.add(videoCodec);
    return hardwareEncoder;
  }

  @override
  Future<VideoData> probe(File video) async {
    if (probeFails) throw const MediaException('probe failed');
    return data!;
  }

  @override
  Future<VideoCompressionTask> start({
    required File input,
    required String videoCodec,
    required int crf,
    required String preset,
    required int totalDurationMs,
    required void Function(int percent) onProgress,
    int? videoBitrateKbps,
    int? maxShortSide,
    String? hardwareEncoder,
    int? hardwareBitrateKbps,
    int? startMs,
    int? limitMs,
  }) async {
    usedHardwareEncoder = hardwareEncoder;
    usedHardwareBitrateKbps = hardwareBitrateKbps;
    usedBitrateKbps = videoBitrateKbps;
    usedMaxShortSide = maxShortSide;
    usedCodec = videoCodec;
    usedCrf = crf;
    usedPreset = preset;
    usedDurationMs = totalDurationMs;
    onProgress(42);
    return task;
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
  String get videoDestinationLabel => 'Movies/Petit';
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('petit_video_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File fileOfSize(String name, int bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(List.filled(bytes, 0));

  VideoData dataFor(File f,
          {String? codec = 'h264', int? frameRate = 30, int? durationMs}) =>
      VideoData(
        videoFile: f,
        pixelWidth: 1920,
        pixelHeight: 1080,
        videoCodec: codec,
        frameRate: frameRate,
        durationMs: durationMs,
      );

  group('getVcodecConfigFromCodec', () {
    test('maps codecs to encoders', () {
      expect(getVcodecConfigFromCodec('hevc').vcodec, 'libx265');
      expect(getVcodecConfigFromCodec('H264').vcodec, 'libx264');
      expect(getVcodecConfigFromCodec('vp9').vcodec, 'libvpx-vp9');
      expect(getVcodecConfigFromCodec('unknown').vcodec, 'libx264');
    });
  });

  group('CompressVideoUseCase', () {
    test('derives the CRF from the codec and slider, then saves', () async {
      final input = fileOfSize('in.mp4', 1000);
      final compressor = FakeVideoCompressor(data: dataFor(input));
      final saver = FakeSaver();
      final percents = <int>[];

      final job = await CompressVideoUseCase(compressor, saver)(
        input: input,
        qualityPercent: 80,
        preset: 'medium',
        totalDurationMs: 5000,
        onProgress: percents.add,
        onError: (_) => fail('no errors expected'),
      );

      // h264: 18 + 0.8 * (28 - 18) = 26
      expect(compressor.usedCodec, 'libx264');
      expect(compressor.usedCrf, 26);
      expect(compressor.usedPreset, 'medium');
      expect(percents, [42]);

      compressor.task.completer.complete(fileOfSize('out.mp4', 400));
      final outcome = await job.outcome;

      expect(saver.saved.single, endsWith('out.mp4'));
      expect(outcome.originalBytes, 1000);
      expect(outcome.compressedBytes, 400);
      expect(outcome.savedFraction, closeTo(0.6, 1e-9));
      expect(outcome.destinationLabel, 'Movies/Petit');
      expect(outcome.destinationFolder, '/out/folder');
    });

    test('keeps the original when compression does not shrink it', () async {
      final input = fileOfSize('in.mp4', 500);
      final compressor = FakeVideoCompressor(data: dataFor(input));
      final saver = FakeSaver();

      final job = await CompressVideoUseCase(compressor, saver)(
        input: input,
        qualityPercent: 80,
        preset: 'fast',
        totalDurationMs: 1,
        onProgress: (_) {},
        onError: (_) {},
      );
      compressor.task.completer.complete(fileOfSize('out.mp4', 900));
      final outcome = await job.outcome;

      expect(saver.saved.single, input.path);
      expect(outcome.compressedBytes, 500);
      expect(outcome.savedBytes, 0);
    });

    test('a failed compression surfaces a MediaException', () async {
      final input = fileOfSize('in.mp4', 500);
      final compressor = FakeVideoCompressor(data: dataFor(input));

      final job = await CompressVideoUseCase(compressor, FakeSaver())(
        input: input,
        qualityPercent: 80,
        preset: 'fast',
        totalDurationMs: 1,
        onProgress: (_) {},
        onError: (_) {},
      );
      compressor.task.completer
          .completeError(const MediaException('Compression failed.'));

      await expectLater(job.outcome, throwsA(isA<MediaException>()));
    });

    test('missing video properties give the generic message', () async {
      final input = fileOfSize('in.mp4', 500);

      for (final compressor in [
        FakeVideoCompressor(probeFails: true),
        FakeVideoCompressor(data: dataFor(input, frameRate: null)),
        FakeVideoCompressor(data: dataFor(input, codec: null)),
      ]) {
        await expectLater(
          CompressVideoUseCase(compressor, FakeSaver())(
            input: input,
            qualityPercent: 80,
            preset: 'fast',
            totalDurationMs: 1,
            onProgress: (_) {},
            onError: (_) {},
          ),
          throwsA(isA<MediaException>().having(
              (e) => e.message, 'message', 'Error retrieving video properties')),
        );
      }
    });

    test('progress uses the given duration, else the probed one, else 1',
        () async {
      Future<int?> durationUsed({int? given, int? probed}) async {
        final input = fileOfSize('in_${given}_$probed.mp4', 100);
        final compressor =
            FakeVideoCompressor(data: dataFor(input, durationMs: probed));
        await CompressVideoUseCase(compressor, FakeSaver())(
          input: input,
          qualityPercent: 80,
          preset: 'fast',
          totalDurationMs: given,
          onProgress: (_) {},
          onError: (_) {},
        );
        return compressor.usedDurationMs;
      }

      expect(await durationUsed(given: 5000, probed: 9000), 5000);
      expect(await durationUsed(given: null, probed: 9000), 9000);
      expect(await durationUsed(given: 0, probed: 9000), 9000);
      expect(await durationUsed(given: null, probed: null), 1);
      expect(await durationUsed(given: 0, probed: 0), 1);
    });

    test('asks the saver where to save before probing or compressing',
        () async {
      final input = fileOfSize('in.mp4', 500);
      final compressor = FakeVideoCompressor(data: dataFor(input));
      final saver = FakeSaver(declineToPrepare: true);

      await expectLater(
        CompressVideoUseCase(compressor, saver)(
          input: input,
          qualityPercent: 80,
          preset: 'fast',
          onProgress: (_) {},
          onError: (_) {},
        ),
        throwsA(isA<MediaException>()
            .having((e) => e.message, 'message', 'No output folder selected.')),
      );

      expect(saver.prepareCalls, 1);
      expect(compressor.usedCodec, isNull);
    });

    group('resolution and target size', () {
      Future<FakeVideoCompressor> run({
        int? maxShortSide,
        int? targetBytes,
        int? durationMs = 10000,
      }) async {
        final input = fileOfSize('in_${maxShortSide}_$targetBytes.mp4', 100);
        final compressor =
            FakeVideoCompressor(data: dataFor(input, durationMs: durationMs));
        await CompressVideoUseCase(compressor, FakeSaver())(
          input: input,
          qualityPercent: 80,
          preset: 'medium',
          maxShortSide: maxShortSide,
          targetBytes: targetBytes,
          onProgress: (_) {},
          onError: (_) {},
        );
        return compressor;
      }

      test('a smaller resolution is passed on (the video is 1920x1080)', () async {
        expect((await run(maxShortSide: 720)).usedMaxShortSide, 720);
        expect((await run(maxShortSide: 480)).usedMaxShortSide, 480);
      });

      test('a resolution that would not shrink the video is dropped', () async {
        expect((await run(maxShortSide: 1080)).usedMaxShortSide, isNull);
        expect((await run(maxShortSide: 2160)).usedMaxShortSide, isNull);
        expect((await run()).usedMaxShortSide, isNull);
      });

      test('a target size becomes a bitrate from the video length', () async {
        final compressor = await run(targetBytes: 1000000);

        expect(compressor.usedBitrateKbps, 632); // 10 s, see video_bitrate_test
      });

      test('quality mode passes no bitrate', () async {
        expect((await run()).usedBitrateKbps, isNull);
      });

      test('a target size needs the length of the video', () async {
        await expectLater(
          run(targetBytes: 1000000, durationMs: null),
          throwsA(isA<MediaException>().having(
              (e) => e.message, 'message', startsWith('Could not work out'))),
        );
      });
    });

    group('fast encoding', () {
      // A sparse file: 50 MB on paper, so a 10 s video of 40,000 kbit/s.
      File bigFile(String name) {
        final file = File('${dir.path}/$name');
        final handle = file.openSync(mode: FileMode.write);
        handle.setPositionSync(50000000 - 1);
        handle.writeByteSync(0);
        handle.closeSync();
        return file;
      }

      Future<FakeVideoCompressor> run({
        bool fast = true,
        String? hardware = 'h264_videotoolbox',
        String codec = 'h264',
        File? file,
        int? maxShortSide,
        int? targetBytes,
      }) async {
        final input = file ?? bigFile('big_${DateTime.now().microsecondsSinceEpoch}.mp4');
        final compressor = FakeVideoCompressor(
            data: dataFor(input, codec: codec, durationMs: 10000))
          ..hardwareEncoder = hardware;
        await CompressVideoUseCase(compressor, FakeSaver())(
          input: input,
          qualityPercent: 80,
          preset: 'medium',
          maxShortSide: maxShortSide,
          targetBytes: targetBytes,
          fastEncoding: fast,
          onProgress: (_) {},
          onError: (_) {},
        );
        return compressor;
      }

      test('is not even looked for unless asked', () async {
        final compressor = await run(fast: false);

        expect(compressor.hardwareAskedFor, isEmpty);
        expect(compressor.usedHardwareEncoder, isNull);
        expect(compressor.usedHardwareBitrateKbps, isNull);
      });

      test('uses normal encoding when the machine has no hardware for it',
          () async {
        final compressor = await run(hardware: null);

        expect(compressor.hardwareAskedFor, ['libx264']);
        expect(compressor.usedHardwareEncoder, isNull);
        expect(compressor.usedHardwareBitrateKbps, isNull);
      });

      test('gives the hardware a bitrate worked out from the quality', () async {
        final compressor = await run();

        expect(compressor.usedHardwareEncoder, 'h264_videotoolbox');
        // 1080p30 at CRF 26: 0.1 bit/pixel, halved every 6 steps, see
        // fast_encoding_test.
        expect(compressor.usedHardwareBitrateKbps, 4399);
      });

      test('still passes the normal settings, for the retry', () async {
        final compressor = await run();

        expect(compressor.usedCodec, 'libx264');
        expect(compressor.usedCrf, 26);
        expect(compressor.usedPreset, 'medium');
        expect(compressor.usedBitrateKbps, isNull,
            reason: 'quality mode: the retry uses CRF');
      });

      test('never asks for more than the video already has', () async {
        // 100 bytes over 10 s: far below what the quality would ask for.
        final compressor = await run(file: fileOfSize('tiny.mp4', 100));

        expect(compressor.usedHardwareBitrateKbps, 100);
      });

      test('a smaller resolution needs a smaller bitrate', () async {
        final compressor = await run(maxShortSide: 540);

        expect(compressor.usedMaxShortSide, 540);
        expect(compressor.usedHardwareBitrateKbps, 1100); // a quarter of 4399
      });

      test('a target size is the bitrate for the hardware too', () async {
        final compressor = await run(targetBytes: 1000000);

        expect(compressor.usedBitrateKbps, 632);
        expect(compressor.usedHardwareBitrateKbps, 632);
        expect(compressor.usedHardwareEncoder, 'h264_videotoolbox');
      });

      test('HEVC videos look for an HEVC encoder', () async {
        final compressor =
            await run(codec: 'hevc', hardware: 'hevc_videotoolbox');

        expect(compressor.hardwareAskedFor, ['libx265']);
        expect(compressor.usedHardwareEncoder, 'hevc_videotoolbox');
      });
    });

    group('CheckFastEncodingUseCase', () {
      test('is true when the machine has hardware for the codec', () async {
        final compressor = FakeVideoCompressor()..hardwareEncoder = 'h264_nvenc';
        expect(await CheckFastEncodingUseCase(compressor)('h264'), isTrue);
        expect(compressor.hardwareAskedFor, ['libx264']);
      });

      test('is false when it has none', () async {
        expect(await CheckFastEncodingUseCase(FakeVideoCompressor())('h264'),
            isFalse);
      });

      test('maps the probed codec name to the software encoder', () async {
        final compressor = FakeVideoCompressor();
        final check = CheckFastEncodingUseCase(compressor);

        await check('hevc');
        await check('vp9');
        await check('something-new');

        expect(compressor.hardwareAskedFor,
            ['libx265', 'libvpx-vp9', 'libx264']);
      });
    });

    test('cancel is forwarded to the task', () async {
      final input = fileOfSize('in.mp4', 500);
      final compressor = FakeVideoCompressor(data: dataFor(input));

      final job = await CompressVideoUseCase(compressor, FakeSaver())(
        input: input,
        qualityPercent: 80,
        preset: 'fast',
        totalDurationMs: 1,
        onProgress: (_) {},
        onError: (_) {},
      );
      await job.cancel();

      expect(compressor.task.cancelled, isTrue);
    });
  });
}
