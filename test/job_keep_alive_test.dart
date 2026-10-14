import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/data/services/android_background_keep_alive.dart';
import 'package:petit/common/domain/job_keep_alive.dart';

import 'helpers/viewmodel_fakes.dart';

void main() {
  group('JobKeepAlive', () {
    late FakeBackgroundKeepAlive service;
    late DateTime clock;
    late JobKeepAlive keepAlive;

    setUp(() {
      service = FakeBackgroundKeepAlive();
      clock = DateTime(2026, 1, 1);
      keepAlive = JobKeepAlive(service, now: () => clock);
    });

    void pass(Duration time) => clock = clock.add(time);

    test('asks for permission, then starts', () async {
      await keepAlive.begin(title: 'Compressing');

      expect(service.calls, ['permission', 'start:Compressing']);
      expect(keepAlive.isRunning, isTrue);
    });

    test('asks for permission only once, however many jobs', () async {
      await keepAlive.begin(title: 'One');
      await keepAlive.end();
      await keepAlive.begin(title: 'Two');

      expect(service.calls.where((c) => c == 'permission'), hasLength(1));
      expect(service.calls, contains('start:Two'));
    });

    test('begin while running does nothing', () async {
      await keepAlive.begin(title: 'One');
      await keepAlive.begin(title: 'Two');

      expect(service.calls.where((c) => c.startsWith('start')), hasLength(1));
    });

    test('works even if the permission cannot be asked', () async {
      service.failWith = StateError('no channel');
      await keepAlive.begin(title: 'Compressing');

      // Both calls threw; nothing escaped, but it is not running either.
      expect(keepAlive.isRunning, isFalse);
    });

    test('a refused permission still starts', () async {
      service.permission = false;
      await keepAlive.begin(title: 'Compressing');

      expect(keepAlive.isRunning, isTrue);
    });

    group('progress', () {
      setUp(() async => keepAlive.begin(title: 'Compressing'));

      test('is ignored before begin', () {
        final fresh = JobKeepAlive(service, now: () => clock);
        fresh.progress(percent: 10, text: 'x');
        expect(service.calls.where((c) => c.startsWith('update')), isEmpty);
      });

      test('the first one goes through', () {
        keepAlive.progress(percent: 5, text: 'a');
        expect(service.calls.last, 'update:5:a');
      });

      test('the same percent is not sent again', () {
        keepAlive.progress(percent: 5, text: 'a');
        pass(const Duration(seconds: 5));
        keepAlive.progress(percent: 5, text: 'a');

        expect(service.calls.where((c) => c.startsWith('update')), hasLength(1));
      });

      test('updates closer together than the gap are dropped', () {
        keepAlive.progress(percent: 5, text: 'a');
        pass(const Duration(milliseconds: 300));
        keepAlive.progress(percent: 6, text: 'b');

        expect(service.calls.where((c) => c.startsWith('update')), hasLength(1));
      });

      test('an update after the gap goes through', () {
        keepAlive.progress(percent: 5, text: 'a');
        pass(const Duration(seconds: 2));
        keepAlive.progress(percent: 6, text: 'b');

        expect(service.calls.last, 'update:6:b');
      });

      test('100% always goes through', () {
        keepAlive.progress(percent: 98, text: 'a');
        pass(const Duration(milliseconds: 10));
        keepAlive.progress(percent: 100, text: 'done');

        expect(service.calls.last, 'update:100:done');
      });

      test('the percent is kept within 0 and 100', () {
        keepAlive.progress(percent: 250, text: 'a');
        expect(service.calls.last, 'update:100:a');
      });

      test('a failing update is swallowed', () async {
        service.failWith = StateError('gone');
        keepAlive.progress(percent: 5, text: 'a');
        await Future<void>.delayed(Duration.zero);
        // Reaching here without an unhandled error is the test.
        expect(keepAlive.isRunning, isTrue);
      });
    });

    group('end', () {
      test('stops once', () async {
        await keepAlive.begin(title: 'Compressing');
        await keepAlive.end();
        await keepAlive.end();

        expect(service.calls.where((c) => c == 'stop'), hasLength(1));
        expect(keepAlive.isRunning, isFalse);
      });

      test('does nothing when never started', () async {
        await keepAlive.end();
        expect(service.calls, isEmpty);
      });

      test('a failing stop is swallowed', () async {
        await keepAlive.begin(title: 'Compressing');
        service.failWith = StateError('gone');

        await keepAlive.end();

        expect(keepAlive.isRunning, isFalse);
      });
    });
  });

  group('AndroidBackgroundKeepAlive', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    const channel = MethodChannel(AndroidBackgroundKeepAlive.channelName);
    final seen = <MethodCall>[];
    Object? permissionAnswer = true;

    setUp(() {
      seen.clear();
      permissionAnswer = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        seen.add(call);
        return call.method == 'requestNotificationPermission'
            ? permissionAnswer
            : null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sends start, update and stop with their arguments', () async {
      final keepAlive = AndroidBackgroundKeepAlive();

      await keepAlive.start(title: 'Compressing', text: 'Starting');
      await keepAlive.update(percent: 40, text: 'Image 2 of 5');
      await keepAlive.stop();

      expect(seen.map((c) => c.method), ['start', 'update', 'stop']);
      expect(seen[0].arguments, {'title': 'Compressing', 'text': 'Starting'});
      expect(seen[1].arguments, {'percent': 40, 'text': 'Image 2 of 5'});
    });

    test('reports whether the notification permission was given', () async {
      final keepAlive = AndroidBackgroundKeepAlive();

      expect(await keepAlive.requestNotificationPermission(), isTrue);

      permissionAnswer = false;
      expect(await keepAlive.requestNotificationPermission(), isFalse);

      permissionAnswer = null;
      expect(await keepAlive.requestNotificationPermission(), isFalse);
    });
  });
}
