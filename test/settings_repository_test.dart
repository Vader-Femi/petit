import 'package:flutter_test/flutter_test.dart';
import 'package:petit/features/settings/data/services/shared_prefs_settings_repository.dart';
import 'package:petit/features/settings/domain/entities/app_settings.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/videos/domain/video_bitrate.dart';

void main() {
  group('settingsFromMap', () {
    test('an empty store gives the defaults', () {
      expect(settingsFromMap({}), const AppSettings());
    });

    test('reads stored values', () {
      final s = settingsFromMap({
        'settings_image_quality': 65,
        'settings_keep_transparency': false,
        'settings_remove_location': true,
        'settings_video_use_target_size': true,
        'settings_video_quality': 55,
        'settings_video_resolution': 'p720',
        'settings_video_preset': 2,
        'settings_video_target_size_mb': 50,
        'settings_video_fast_encoding': true,
      });

      expect(
          s,
          const AppSettings(
            imageQuality: 65,
            keepTransparency: false,
            removeLocation: true,
            videoUseTargetSize: true,
            videoQuality: 55,
            videoResolution: VideoResolution.p720,
            videoPresetIndex: 2,
            videoTargetSizeMb: 50,
            videoFastEncoding: true,
          ));
    });

    test('out of range numbers are pulled into range', () {
      final s = settingsFromMap({
        'settings_image_quality': 900,
        'settings_video_quality': -3,
        'settings_video_preset': 7,
        'settings_video_target_size_mb': 0,
      });

      expect(s.imageQuality, 100);
      expect(s.videoQuality, 0);
      expect(s.videoPresetIndex, AppSettings.maxVideoPresetIndex);
      expect(s.videoTargetSizeMb, 1);
      expect(
          settingsFromMap({'settings_video_target_size_mb': 50000})
              .videoTargetSizeMb,
          kMaxTargetSizeMb);
    });

    test('wrong types and unknown names keep the defaults', () {
      final s = settingsFromMap({
        'settings_image_quality': 'high',
        'settings_keep_transparency': 1,
        'settings_video_fast_encoding': 'yes',
        'settings_video_resolution': '4k',
      });

      expect(s, const AppSettings());
    });
  });
}
