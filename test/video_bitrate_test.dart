import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';

void main() {
  group('bitrateForTargetSize', () {
    test('turns a target size and a length into a video bitrate', () {
      // 1,000,000 bytes over 10 s: 1e6 * 8 * 0.95 / 10 s = 760 kbit/s in total,
      // minus 128 kbit/s of audio.
      expect(bitrateForTargetSize(targetBytes: 1000000, durationMs: 10000), 632);
    });

    test('longer clips get lower bitrates for the same size', () {
      final short = bitrateForTargetSize(targetBytes: 25000000, durationMs: 60000);
      final long = bitrateForTargetSize(targetBytes: 25000000, durationMs: 120000);
      expect(short, greaterThan(long));
    });

    test('never goes below the minimum', () {
      expect(bitrateForTargetSize(targetBytes: 100000, durationMs: 60000),
          kMinVideoKbps);
    });

    test('the audio allowance can be changed', () {
      expect(
        bitrateForTargetSize(
            targetBytes: 1000000, durationMs: 10000, audioKbps: 64),
        696,
      );
    });
  });

  group('VideoResolution', () {
    test('sizes are the length of the shorter side', () {
      expect(VideoResolution.original.shortSide, isNull);
      expect(VideoResolution.p1080.shortSide, 1080);
      expect(VideoResolution.p720.shortSide, 720);
      expect(VideoResolution.p480.shortSide, 480);
      expect(VideoResolution.p720.label, '720p');
    });
  });
}
