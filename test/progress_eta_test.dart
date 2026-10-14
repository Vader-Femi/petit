import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/domain/progress_eta.dart';
import 'package:petit/core/utils/format_eta.dart';
import 'package:petit/features/images/presentation/state/loading_data.dart';

void main() {
  group('ProgressEta', () {
    late DateTime clock;
    late ProgressEta eta;

    setUp(() {
      clock = DateTime(2026, 1, 1);
      eta = ProgressEta(now: () => clock);
    });

    void pass(int seconds) => clock = clock.add(Duration(seconds: seconds));

    test('knows nothing before it is started', () {
      eta.update(0.5);
      expect(eta.remaining, isNull);
    });

    test('is silent while it is too early to tell', () {
      eta.start();
      pass(1);
      eta.update(0.5); // far along, but only one second of data
      expect(eta.remaining, isNull);

      pass(10);
      eta.update(0.01); // plenty of time, but barely started
      expect(eta.remaining, isNull);
    });

    test('works out the time left from the pace so far', () {
      eta.start();
      pass(10);
      eta.update(0.25); // 10 s for a quarter: 30 s to go
      expect(eta.remaining, const Duration(seconds: 30));
    });

    test('blends later readings instead of jumping', () {
      eta.start();
      pass(10);
      eta.update(0.25); // reading 30 s
      pass(10);
      eta.update(0.30); // raw: 20 s * 0.7 / 0.3 = 46.67 s

      final seconds = eta.remaining!.inMilliseconds / 1000;
      // 70% of 30 s plus 30% of 46.67 s.
      expect(seconds, closeTo(35.0, 0.01));
    });

    test('is zero once the job is done', () {
      eta.start();
      pass(10);
      eta.update(0.5);
      eta.update(1.0);
      expect(eta.remaining, Duration.zero);
    });

    test('start forgets the previous job', () {
      eta.start();
      pass(10);
      eta.update(0.5);
      expect(eta.remaining, isNotNull);

      eta.start();
      expect(eta.remaining, isNull);
    });

    test('reset forgets everything', () {
      eta.start();
      pass(10);
      eta.update(0.5);
      eta.reset();
      expect(eta.remaining, isNull);
      pass(10);
      eta.update(0.5);
      expect(eta.remaining, isNull, reason: 'not started again');
    });
  });

  group('formatEta', () {
    test('a few seconds', () {
      expect(formatEta(Duration.zero), 'a few seconds left');
      expect(formatEta(const Duration(seconds: 9)), 'a few seconds left');
    });

    test('seconds are rounded to five', () {
      expect(formatEta(const Duration(seconds: 10)), 'about 10 seconds left');
      expect(formatEta(const Duration(seconds: 33)), 'about 35 seconds left');
    });

    test('nearly a minute reads as a minute', () {
      expect(formatEta(const Duration(seconds: 58)), 'about 1 minute left');
      expect(formatEta(const Duration(seconds: 60)), 'about 1 minute left');
    });

    test('minutes round up', () {
      expect(formatEta(const Duration(seconds: 61)), 'about 2 minutes left');
      expect(formatEta(const Duration(minutes: 5)), 'about 5 minutes left');
      expect(
          formatEta(const Duration(minutes: 5, seconds: 1)),
          'about 6 minutes left');
    });

    test('hours', () {
      expect(formatEta(const Duration(hours: 2)), 'about 2 h left');
      expect(formatEta(const Duration(hours: 1, minutes: 20)),
          'about 1 h 20 min left');
    });
  });

  group('LoadingData eta', () {
    test('is part of equality', () {
      const a = LoadingData(isLoading: true, eta: Duration(seconds: 5));
      const b = LoadingData(isLoading: true, eta: Duration(seconds: 5));
      const c = LoadingData(isLoading: true, eta: Duration(seconds: 6));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
