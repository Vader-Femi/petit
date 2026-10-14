import 'package:petit/features/settings/domain/entities/app_settings.dart';
import 'package:petit/features/settings/domain/services/settings_repository.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _imageQuality = 'settings_image_quality';
const _keepTransparency = 'settings_keep_transparency';
const _removeLocation = 'settings_remove_location';
const _videoUseTargetSize = 'settings_video_use_target_size';
const _videoQuality = 'settings_video_quality';
const _videoResolution = 'settings_video_resolution';
const _videoPreset = 'settings_video_preset';
const _videoTargetSizeMb = 'settings_video_target_size_mb';
const _videoFastEncoding = 'settings_video_fast_encoding';

const _allKeys = {
  _imageQuality,
  _keepTransparency,
  _removeLocation,
  _videoUseTargetSize,
  _videoQuality,
  _videoResolution,
  _videoPreset,
  _videoTargetSizeMb,
  _videoFastEncoding,
};

/// Builds settings from stored values. Missing, wrongly typed or out of range
/// values keep their default, so a damaged or older store never breaks start-up.
AppSettings settingsFromMap(Map<String, Object?> values) {
  const defaults = AppSettings();

  int intIn(String key, int fallback, int min, int max) {
    final value = values[key];
    return value is int ? value.clamp(min, max).toInt() : fallback;
  }

  bool boolOf(String key, bool fallback) {
    final value = values[key];
    return value is bool ? value : fallback;
  }

  final resolutionName = values[_videoResolution];
  final resolution = VideoResolution.values.firstWhere(
    (r) => r.name == resolutionName,
    orElse: () => defaults.videoResolution,
  );

  return AppSettings(
    imageQuality: intIn(_imageQuality, defaults.imageQuality, 0, 100),
    keepTransparency: boolOf(_keepTransparency, defaults.keepTransparency),
    removeLocation: boolOf(_removeLocation, defaults.removeLocation),
    videoUseTargetSize:
        boolOf(_videoUseTargetSize, defaults.videoUseTargetSize),
    videoQuality: intIn(_videoQuality, defaults.videoQuality, 0, 100),
    videoResolution: resolution,
    videoPresetIndex: intIn(_videoPreset, defaults.videoPresetIndex, 0,
        AppSettings.maxVideoPresetIndex),
    videoTargetSizeMb:
        intIn(_videoTargetSizeMb, defaults.videoTargetSizeMb, 1, kMaxTargetSizeMb),
    videoFastEncoding:
        boolOf(_videoFastEncoding, defaults.videoFastEncoding),
  );
}

class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<AppSettings> load() async {
    final all = await _prefs.getAll(allowList: _allKeys);
    return settingsFromMap(all);
  }

  @override
  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_imageQuality, s.imageQuality);
    await _prefs.setBool(_keepTransparency, s.keepTransparency);
    await _prefs.setBool(_removeLocation, s.removeLocation);
    await _prefs.setBool(_videoUseTargetSize, s.videoUseTargetSize);
    await _prefs.setInt(_videoQuality, s.videoQuality);
    await _prefs.setString(_videoResolution, s.videoResolution.name);
    await _prefs.setInt(_videoPreset, s.videoPresetIndex);
    await _prefs.setInt(_videoTargetSizeMb, s.videoTargetSizeMb);
    await _prefs.setBool(_videoFastEncoding, s.videoFastEncoding);
  }
}
