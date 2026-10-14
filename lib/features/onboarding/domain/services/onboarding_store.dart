/// Remembers whether the welcome screens have been seen.
abstract interface class OnboardingStore {
  Future<bool> isDone();

  Future<void> markDone();
}
