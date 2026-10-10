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
  }) async {
    usedCodec = videoCodec;
    usedCrf = crf;
    usedPreset = preset;
    onProgress(42);
    return task;
  }
}

class FakeSaver implements MediaSaver {
  final saved = <String>[];

  @override
  Future<void> saveImage(String path) async => saved.add(path);

  @override
  Future<void> saveVideo(String path) async => saved.add(path);

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

  VideoData dataFor(File f, {String? codec = 'h264', int? frameRate = 30}) =>
      VideoData(
        videoFile: f,
        pixelWidth: 1920,
        pixelHeight: 1080,
        videoCodec: codec,
        frameRate: frameRate,
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
