import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';
import 'package:petit/features/videos/domain/video_warnings.dart';

List<VideoSettingsWarning> warningsFor({
  bool aimsForSize = false,
  int qualityPercent = 80,
  int targetMb = 25,
  bool downscales = false,
  int? videoBytes = 100000000,
  int? durationMs = 60000,
}) =>
    videoSettingsWarnings(
      aimsForSize: aimsForSize,
      qualityPercent: qualityPercent,
      targetMb: targetMb,
      downscales: downscales,
      videoBytes: videoBytes,
      durationMs: durationMs,
    );

void main() {
  group('minimumTargetBytes', () {
    test('is the size at the lowest bitrate', () {
      // 100 + 128 kbit/s for 60 s, plus the 5% held back: 1,800,000 bytes.
      expect(minimumTargetBytes(durationMs: 60000), 1800000);
    });

    test('is where bitrateForTargetSize stops going lower', () {
      final floor = minimumTargetBytes(durationMs: 60000);
      expect(bitrateForTargetSize(targetBytes: floor, durationMs: 60000),
          kMinVideoKbps);
      expect(bitrateForTargetSize(targetBytes: floor ~/ 2, durationMs: 60000),
          kMinVideoKbps);
      expect(
          bitrateForTargetSize(targetBytes: floor * 2, durationMs: 60000),
          greaterThan(kMinVideoKbps));
    });
  });

  group('target size', () {
    test('no warning for a sensible target', () {
      expect(warningsFor(aimsForSize: true, targetMb: 25), isEmpty);
    });

    test('a target that is not smaller than the video blocks starting', () {
      final w = warningsFor(aimsForSize: true, targetMb: 100);
      expect(w.single.blocksStart, isTrue);
      expect(w.single.message, contains('100 MB'));
    });

    test('a target far below what the length allows is a warning only', () {
      final w = warningsFor(aimsForSize: true, targetMb: 1, durationMs: 600000);
      expect(w.single.blocksStart, isFalse);
      expect(w.single.message, contains('cannot get below'));
    });

    test('unknown size and length give no target warnings', () {
      expect(
          warningsFor(
              aimsForSize: true,
              targetMb: 1,
              videoBytes: null,
              durationMs: null),
          isEmpty);
    });

    test('quality hints are not shown while aiming for a size', () {
      expect(
          warningsFor(aimsForSize: true, qualityPercent: 0, targetMb: 25),
          isEmpty);
    });
  });

  group('quality', () {
    test('no warning at the recommended level', () {
      expect(warningsFor(qualityPercent: 80), isEmpty);
    });

    test('minimal compression may not shrink the video', () {
      final w = warningsFor(qualityPercent: 20);
      expect(w.single.blocksStart, isFalse);
      expect(w.single.message, contains('Minimal'));
    });

    test('a video that is already small may not shrink', () {
      // 1,000,000 bytes over 60 s is about 133 kbit/s.
      final w = warningsFor(videoBytes: 1000000);
      expect(w.single.message, contains('already small'));
      expect(w.single.blocksStart, isFalse);
    });

    test('a normal bitrate gets no warning', () {
      // 100,000,000 bytes over 60 s is about 13,300 kbit/s.
      expect(warningsFor(videoBytes: 100000000), isEmpty);
    });

    test('a smaller resolution is itself a reason to expect a smaller file',
        () {
      expect(warningsFor(qualityPercent: 0, downscales: true), isEmpty);
      expect(warningsFor(videoBytes: 1000000, downscales: true), isEmpty);
    });

    test('without a length only the level can warn', () {
      expect(warningsFor(videoBytes: 1000000, durationMs: null), isEmpty);
      expect(warningsFor(qualityPercent: 10, durationMs: null), hasLength(1));
    });
  });
}
