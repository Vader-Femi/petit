import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit/core/di/providers.dart';
import 'package:petit/features/onboarding/domain/services/onboarding_store.dart';
import 'package:petit/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:petit/features/onboarding/presentation/state/onboarding_viewmodel.dart';

class _FakeStore implements OnboardingStore {
  int marked = 0;
  bool fail = false;

  @override
  Future<bool> isDone() async => marked > 0;

  @override
  Future<void> markDone() async {
    marked++;
    if (fail) throw StateError('disk full');
  }
}

void main() {
  group('OnboardingViewModel', () {
    ProviderContainer containerWith(bool alreadySeen, _FakeStore store) =>
        ProviderContainer.test(overrides: [
          initialOnboardingDoneProvider.overrideWithValue(alreadySeen),
          onboardingStoreProvider.overrideWithValue(store),
        ]);

    test('starts from whether it was seen at launch', () {
      expect(
          containerWith(false, _FakeStore()).read(onboardingDoneProvider),
          isFalse);
      expect(containerWith(true, _FakeStore()).read(onboardingDoneProvider),
          isTrue);
    });

    test('completing it is remembered', () {
      final store = _FakeStore();
      final c = containerWith(false, store);

      c.read(onboardingDoneProvider.notifier).complete();

      expect(c.read(onboardingDoneProvider), isTrue);
      expect(store.marked, 1);
    });

    test('completing twice saves once', () {
      final store = _FakeStore();
      final c = containerWith(false, store);

      c.read(onboardingDoneProvider.notifier).complete();
      c.read(onboardingDoneProvider.notifier).complete();

      expect(store.marked, 1);
    });

    test('a failed save still lets the user in', () async {
      final store = _FakeStore()..fail = true;
      final c = containerWith(false, store);

      c.read(onboardingDoneProvider.notifier).complete();
      await Future<void>.delayed(Duration.zero);

      expect(c.read(onboardingDoneProvider), isTrue);
    });

    test('without a stored answer the screens are skipped', () {
      // Nothing is registered with get_it in tests, as when reading failed.
      final c = ProviderContainer.test();
      expect(c.read(onboardingDoneProvider), isTrue);
    });
  });

  group('OnboardingScreen', () {
    Future<void> show(WidgetTester tester, VoidCallback onFinished) {
      return tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(onFinished: onFinished),
      ));
    }

    testWidgets('starts on the welcome page', (tester) async {
      await show(tester, () {});
      expect(find.text('Welcome to Petit'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('Next moves through the pages to Get started', (tester) async {
      var finished = 0;
      await show(tester, () => finished++);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Pick, preview, compress'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Your files stay yours'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(finished, 0);

      await tester.tap(find.text('Get started'));
      expect(finished, 1);
    });

    testWidgets('Skip finishes at once', (tester) async {
      var finished = 0;
      await show(tester, () => finished++);

      await tester.tap(find.text('Skip'));

      expect(finished, 1);
    });

    testWidgets('Skip cannot be used on the last page', (tester) async {
      var finished = 0;
      await show(tester, () => finished++);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'), warnIfMissed: false);

      expect(finished, 0);
    });

    testWidgets('swiping works too', (tester) async {
      await show(tester, () {});

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Pick, preview, compress'), findsOneWidget);
    });
  });
}
