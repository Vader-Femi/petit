import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/usecases/estimate_video_size.dart';

class _Task implements VideoCompressionTask {
  _Task(this.file);

  final Completer<File> _completer = Completer<File>();
  final File? file;
  bool cancelled = false;

  @override
  Future<File> get result => _completer.future;

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!_completer.isCompleted) {
      _completer.completeError(const MediaException('cancelled'));
    }
  }
}

/// Writes a sample of [bytesPerSecond] for each second it is asked to cover.
class _SamplingCompressor implements VideoCompressor {
  _SamplingCompressor(this.dir, {this.durationMs = 60000, this.hold = false});

  final Directory dir;
  final int? durationMs;
  final bool hold;
  int bytesPerSecond = 1000;
  String? hardware;
  final calls = <Map<String, Object?>>[];
  final tasks = <_Task>[];

  @override
  Future<String?> hardwareEncoderFor(String videoCodec) async => hardware;

  @override
  Future<VideoData> probe(File video) async => VideoData(
        videoFile: video,
        pixelWidth: 1920,
        pixelHeight: 1080,
        videoCodec: 'h264',
        frameRate: 30,
        durationMs: durationMs,
      );

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
    calls.add({
      'codec': videoCodec,
      'crf': crf,
      'bitrate': videoBitrateKbps,
      'scale': maxShortSide,
      'hardware': hardwareEncoder,
      'hardwareBitrate': hardwareBitrateKbps,
      'start': startMs,
      'limit': limitMs,
      'total': totalDurationMs,
    });
    final bytes = (limitMs ?? 0) * bytesPerSecond ~/ 1000;
    final out = File('${dir.path}/sample_${calls.length}.bin');
    out.writeAsBytesSync(List.filled(bytes, 1));
    final task = _Task(out);
    tasks.add(task);
    if (!hold) {
      onProgress(50);
      task._completer.complete(out);
    }
    return task;
  }
}

void main() {
  late Directory dir;
  late File input;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('petit_estimate_video_');
    input = File('${dir.path}/in.mp4')..writeAsBytesSync(List.filled(100000, 0));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<VideoSizeEstimate> estimate(
    _SamplingCompressor compressor, {
    int quality = 80,
    int? target,
    int? scale,
    bool fast = false,
    void Function(int)? onProgress,
  }) async {
    final job = await EstimateVideoSizeUseCase(compressor)(
      input: input,
      qualityPercent: quality,
      preset: 'medium',
      maxShortSide: scale,
      targetBytes: target,
      fastEncoding: fast,
      onProgress: onProgress,
    );
    return job.result;
  }

  test('compresses three short samples of a long video and scales them up',
      () async {
    final compressor = _SamplingCompressor(dir)..bytesPerSecond = 1000;

    final result = await estimate(compressor);

    expect(compressor.calls.map((c) => (c['start'], c['limit'])),
        [(9000, 2000), (29000, 2000), (49000, 2000)]);
    // 2000 bytes per sample, 6 s sampled, 60 s in all.
    expect(result.estimatedBytes, 60000);
    expect(result.originalBytes, 100000);
    expect(result.sampleCount, 3);
    expect(result.sampledMs, 6000);
    expect(result.totalMs, 60000);
    expect(result.isExact, isFalse);
    expect(result.isLarger, isFalse);
    expect(result.savedFraction, closeTo(0.4, 1e-9));
  });

  test('a short video is compressed whole, so the answer is exact', () async {
    final compressor = _SamplingCompressor(dir, durationMs: 5000)
      ..bytesPerSecond = 2000;

    final result = await estimate(compressor);

    expect(compressor.calls.length, 1);
    expect(compressor.calls.single['start'], 0);
    expect(compressor.calls.single['limit'], 5000);
    expect(result.estimatedBytes, 10000);
    expect(result.isExact, isTrue);
  });

  test('says when compressing would not make the video smaller', () async {
    final compressor = _SamplingCompressor(dir)..bytesPerSecond = 5000;

    final result = await estimate(compressor); // 300,000 bytes for 100,000

    expect(result.isLarger, isTrue);
    expect(result.savedFraction, 0.0);
  });

  test('the samples are deleted afterwards, the original is not', () async {
    final compressor = _SamplingCompressor(dir);

    await estimate(compressor);

    for (var i = 1; i <= 3; i++) {
      expect(File('${dir.path}/sample_$i.bin').existsSync(), isFalse);
    }
    expect(input.existsSync(), isTrue);
  });

  test('uses the same settings as compressing would', () async {
    final compressor = _SamplingCompressor(dir);

    await estimate(compressor, quality: 80, scale: 720);

    final call = compressor.calls.first;
    expect(call['codec'], 'libx264');
    expect(call['crf'], 26); // 18 + 0.8 x 10
    expect(call['scale'], 720);
    expect(call['bitrate'], isNull);
    expect(call['hardware'], isNull);
  });

  test('a target size makes every sample aim for its bitrate', () async {
    final compressor = _SamplingCompressor(dir);

    await estimate(compressor, target: 5000000);

    final bitrates = compressor.calls.map((c) => c['bitrate']).toSet();
    expect(bitrates.length, 1);
    expect(bitrates.single, isNotNull);
  });

  test('uses the video hardware when asked and available', () async {
    final compressor = _SamplingCompressor(dir)..hardware = 'h264_nvenc';

    await estimate(compressor, fast: true);

    expect(compressor.calls.first['hardware'], 'h264_nvenc');
    expect(compressor.calls.first['hardwareBitrate'], isNotNull);
  });

  test('each sample is told its own length, for progress', () async {
    final compressor = _SamplingCompressor(dir);

    await estimate(compressor);

    expect(compressor.calls.map((c) => c['total']), [2000, 2000, 2000]);
  });

  test('progress runs across all the samples and ends at 100', () async {
    final compressor = _SamplingCompressor(dir);
    final seen = <int>[];

    await estimate(compressor, onProgress: seen.add);

    expect(seen.last, 100);
    final sorted = [...seen]..sort();
    expect(seen, sorted, reason: 'never goes backwards');
    expect(seen.first, greaterThan(0));
  });

  test('a video of unknown length cannot be estimated', () async {
    final compressor = _SamplingCompressor(dir, durationMs: null);

    await expectLater(
      estimate(compressor),
      throwsA(isA<MediaException>().having(
          (e) => e.message, 'message', contains('cannot be estimated'))),
    );
    expect(compressor.calls, isEmpty);
  });

  test('a video that cannot be read gives the usual message', () async {
    final failing = _FailingProbe();

    await expectLater(
      EstimateVideoSizeUseCase(failing)(
          input: input, qualityPercent: 80, preset: 'medium'),
      throwsA(isA<MediaException>().having((e) => e.message, 'message',
          'Error retrieving video properties')),
    );
  });

  test('a sample that fails fails the estimate', () async {
    final compressor = _SamplingCompressor(dir, hold: true);
    final job = await EstimateVideoSizeUseCase(compressor)(
        input: input, qualityPercent: 80, preset: 'medium');
    await pumpEventQueue();

    compressor.tasks.first._completer
        .completeError(const MediaException('Compression failed.'));

    await expectLater(job.result, throwsA(isA<MediaException>()));
  });

  test('cancelling stops the sample in progress and starts no more', () async {
    final compressor = _SamplingCompressor(dir, hold: true);
    final job = await EstimateVideoSizeUseCase(compressor)(
        input: input, qualityPercent: 80, preset: 'medium');
    await pumpEventQueue();
    expect(compressor.calls.length, 1);

    // Listen first: the failure arrives while cancelling.
    final failure = expectLater(job.result, throwsA(isA<MediaException>()));
    await job.cancel();

    await failure;
    expect(compressor.tasks.first.cancelled, isTrue);
    expect(compressor.calls.length, 1, reason: 'no second sample');
  });
}

class _FailingProbe implements VideoCompressor {
  @override
  Future<VideoData> probe(File video) async =>
      throw const MediaException('nope');

  @override
  Future<String?> hardwareEncoderFor(String videoCodec) async => null;

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
  }) =>
      throw UnimplementedError();
}
