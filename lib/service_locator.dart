import 'package:get_it/get_it.dart';
import 'package:petit/common/data/services/android_background_keep_alive.dart';
import 'package:petit/common/data/services/file_selector_folder_picker.dart';
import 'package:petit/common/data/services/file_selector_media_picker.dart';
import 'package:petit/common/data/services/folder_media_saver.dart';
import 'package:petit/common/data/services/gallery_media_saver.dart';
import 'package:petit/common/data/services/image_picker_media_picker.dart';
import 'package:petit/common/data/services/noop_background_keep_alive.dart';
import 'package:petit/common/data/services/shared_prefs_output_folder_preference.dart';
import 'package:petit/common/data/services/temp_workspace.dart';
import 'package:petit/common/domain/services/background_keep_alive.dart';
import 'package:petit/common/domain/services/folder_picker.dart';
import 'package:petit/common/domain/services/media_picker.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/common/domain/services/output_folder_preference.dart';
import 'package:petit/common/domain/services/workspace.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/features/images/data/services/desktop_image_compressor.dart';
import 'package:petit/features/images/data/services/flutter_image_compressor.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';
import 'package:petit/features/images/domain/usecases/compress_images.dart';
import 'package:petit/features/images/domain/usecases/estimate_image_size.dart';
import 'package:petit/features/images/domain/usecases/read_images.dart';
import 'package:petit/features/videos/data/services/ffmpeg_video_compressor.dart';
import 'package:petit/features/videos/data/services/ffmpeg_video_thumbnailer.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/services/video_thumbnailer.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:petit/features/onboarding/data/services/shared_prefs_onboarding_store.dart';
import 'package:petit/features/onboarding/domain/services/onboarding_store.dart';
import 'package:petit/features/settings/data/services/shared_prefs_settings_repository.dart';
import 'package:petit/features/settings/domain/entities/app_settings.dart';
import 'package:petit/features/settings/domain/services/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

/// Name under which "welcome screens seen" is registered (a bare bool).
const kOnboardingDoneInstance = 'onboardingDone';

Future<void> initializeDependencies() async {

  //Pref
  sl.registerSingleton<SharedPreferencesAsync>(
      SharedPreferencesAsync()
  );

  _registerMediaDependencies();

  // Android keeps compressing in the background through a foreground service.
  sl.registerLazySingleton<BackgroundKeepAlive>(() => PlatformInfo.isAndroid
      ? AndroidBackgroundKeepAlive()
      : NoopBackgroundKeepAlive());

  // The default settings are read once, here, so the ViewModels can use them
  // from their first build without waiting.
  final settingsRepository = SharedPrefsSettingsRepository(
      sl<SharedPreferencesAsync>());
  sl.registerSingleton<SettingsRepository>(settingsRepository);
  try {
    sl.registerSingleton<AppSettings>(await settingsRepository.load());
  } catch (_) {
    // Start with the defaults; initialSettingsProvider falls back to them.
  }

  // Whether the welcome screens were seen, read once for the same reason.
  final onboardingStore = SharedPrefsOnboardingStore(
      sl<SharedPreferencesAsync>());
  sl.registerSingleton<OnboardingStore>(onboardingStore);
  try {
    sl.registerSingleton<bool>(await onboardingStore.isDone(),
        instanceName: kOnboardingDoneInstance);
  } catch (_) {
    // Treated as seen; see initialOnboardingDoneProvider.
  }
}

/// Platform services are registered here, so the ViewModels and use cases
/// only ever see the domain interfaces.
void _registerMediaDependencies() {
  if (PlatformInfo.isDesktop) {
    // Windows, macOS, Linux: OS file dialogs, a folder to save into, and an
    // image compressor that does not rely on mobile-only plugins.
    sl.registerLazySingleton<MediaPicker>(() => FileSelectorMediaPicker());
    sl.registerLazySingleton<MediaSaver>(() =>
        FolderMediaSaver(sl<FolderPicker>(), sl<OutputFolderPreference>()));
    sl.registerLazySingleton<ImageCompressor>(() => DesktopImageCompressor());
  } else {
    // Android and iOS (and the frozen web build, which never resolves these).
    sl.registerLazySingleton<MediaPicker>(() => ImagePickerMediaPicker());
    sl.registerLazySingleton<MediaSaver>(() => GalleryMediaSaver());
    sl.registerLazySingleton<ImageCompressor>(() => FlutterImageCompressor());
  }

  // The "Save to" setting (only shown on desktop).
  sl.registerLazySingleton<FolderPicker>(() => FileSelectorFolderPicker());
  sl.registerLazySingleton<OutputFolderPreference>(
      () => SharedPrefsOutputFolderPreference(sl<SharedPreferencesAsync>()));

  // Shared: FFmpeg Kit supports Android, iOS, macOS, Windows and Linux.
  sl.registerLazySingleton<Workspace>(() => TempWorkspace());
  sl.registerLazySingleton<VideoCompressor>(() => FfmpegVideoCompressor());
  sl.registerLazySingleton<VideoThumbnailer>(() => FfmpegVideoThumbnailer());

  // Use cases
  sl.registerLazySingleton<ReadImagesUseCase>(
      () => ReadImagesUseCase(sl<ImageCompressor>()));
  sl.registerLazySingleton<EstimateImageSizeUseCase>(
      () => EstimateImageSizeUseCase(sl<ImageCompressor>()));
  sl.registerLazySingleton<CompressImagesUseCase>(
      () => CompressImagesUseCase(sl<ImageCompressor>(), sl<MediaSaver>()));
  sl.registerLazySingleton<CompressVideoUseCase>(
      () => CompressVideoUseCase(sl<VideoCompressor>(), sl<MediaSaver>()));
}
