import 'package:petit/features/onboarding/domain/services/onboarding_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _onboardingDone = 'onboarding_done';

class SharedPrefsOnboardingStore implements OnboardingStore {
  SharedPrefsOnboardingStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<bool> isDone() async => await _prefs.getBool(_onboardingDone) ?? false;

  @override
  Future<void> markDone() => _prefs.setBool(_onboardingDone, true);
}
