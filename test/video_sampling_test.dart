import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/videos/domain/video_sampling.dart';

void main() {
  group('sampleWindows', () {
    test('a short video is its own sample', () {
      expect(sampleWindows(5000), [const SampleWindow(0, 5000)]);
      expect(sampleWindows(kWholeVideoMaxMs),
          [const SampleWindow(0, kWholeVideoMaxMs)]);
    });

    test('a longer one gets three samples spread over it', () {
      // Centres at a sixth, half and five sixths of 60 s, 2 s each.
      expect(sampleWindows(60000), const [
        SampleWindow(9000, 2000),
        SampleWindow(29000, 2000),
        SampleWindow(49000, 2000),
      ]);
    });

    test('samples never run past the end or before the start', () {
      for (final duration in [8001, 9000, 12000, 600000, 7200000]) {
        for (final w in sampleWindows(duration)) {
          expect(w.startMs, greaterThanOrEqualTo(0), reason: '$duration');
          expect(w.startMs + w.lengthMs, lessThanOrEqualTo(duration),
              reason: '$duration');
        }
      }
    });

    test('samples do not overlap', () {
      final windows = sampleWindows(8001);
      for (var i = 1; i < windows.length; i++) {
        expect(windows[i].startMs,
            greaterThanOrEqualTo(windows[i - 1].startMs + windows[i - 1].lengthMs));
      }
    });

    test('the number and length can be changed', () {
      expect(sampleWindows(100000, count: 1, sampleMs: 4000),
          [const SampleWindow(48000, 4000)]);
      expect(sampleWindows(100000, count: 4).length, 4);
    });

    test('no samples asked for means the whole video', () {
      expect(sampleWindows(60000, count: 0), [const SampleWindow(0, 60000)]);
    });
  });

  group('extrapolateBytes', () {
    test('scales the sample rate up to the whole video', () {
      final windows = sampleWindows(60000); // 6 s sampled
      expect(
        extrapolateBytes(
            sampleBytes: [100, 200, 300], windows: windows, durationMs: 60000),
        6000, // 600 bytes in 6 s = 100 B/s, for 60 s
      );
    });

    test('a whole-video sample gives its own size back', () {
      expect(
        extrapolateBytes(
            sampleBytes: [4321],
            windows: sampleWindows(5000),
            durationMs: 5000),
        4321,
      );
    });

    test('nothing sampled gives zero', () {
      expect(
          extrapolateBytes(
              sampleBytes: [], windows: const [], durationMs: 60000),
          0);
    });
  });
}
