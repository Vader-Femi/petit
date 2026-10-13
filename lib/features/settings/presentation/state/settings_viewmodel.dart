import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/core/di/providers.dart';
import 'package:petit/features/settings/domain/entities/app_settings.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, AppSettings>(SettingsViewModel.new);

/// ViewModel of the Settings tab. Its state is the user's default settings,
/// loaded before the app starts so the other tabs can read them at once.
/// Every change is saved right away.
class SettingsViewModel extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  void setImageQuality(int value) =>
      _apply(state.copyWith(imageQuality: value.clamp(0, 100).toInt()));

  void setKeepTransparency(bool value) =>
      _apply(state.copyWith(keepTransparency: value));

  void setRemoveLocation(bool value) =>
      _apply(state.copyWith(removeLocation: value));

  void setVideoUseTargetSize(bool value) =>
      _apply(state.copyWith(videoUseTargetSize: value));

  void setVideoQuality(int value) =>
      _apply(state.copyWith(videoQuality: value.clamp(0, 100).toInt()));

  void setVideoResolution(VideoResolution value) =>
      _apply(state.copyWith(videoResolution: value));

  void setVideoPresetIndex(int value) => _apply(state.copyWith(
      videoPresetIndex:
          value.clamp(0, AppSettings.maxVideoPresetIndex).toInt()));

  void setVideoTargetSizeMb(int value) =>
      _apply(state.copyWith(videoTargetSizeMb: value));

  void resetToDefaults() => _apply(const AppSettings());

  void _apply(AppSettings next) {
    if (next == state) return;
    state = next;
    unawaited(_save(next));
  }

  Future<void> _save(AppSettings settings) async {
    try {
      await ref.read(settingsRepositoryProvider).save(settings);
    } catch (e) {
      // The setting still applies for this run; it just will not be remembered.
      debugPrint('Could not save the settings: $e');
    }
  }
}
