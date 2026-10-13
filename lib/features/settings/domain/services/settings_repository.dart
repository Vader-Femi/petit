import 'package:petit/features/settings/domain/entities/app_settings.dart';

/// Remembers the default settings across app launches.
abstract interface class SettingsRepository {
  /// The saved settings; anything missing or invalid falls back to the default.
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
