import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/core/di/providers.dart';

final onboardingDoneProvider =
    NotifierProvider<OnboardingViewModel, bool>(OnboardingViewModel.new);

/// ViewModel of the welcome screens. Its state is whether they have been seen:
/// false only on the very first launch.
class OnboardingViewModel extends Notifier<bool> {
  @override
  bool build() => ref.read(initialOnboardingDoneProvider);

  /// The user finished or skipped the welcome screens.
  void complete() {
    if (state) return;
    state = true;
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await ref.read(onboardingStoreProvider).markDone();
    } catch (e) {
      // Worst case the welcome screens show once more next launch.
      debugPrint('Could not remember the welcome screens: $e');
    }
  }
}
