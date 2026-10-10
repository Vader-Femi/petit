import 'package:get_it/get_it.dart';
import 'package:petit/common/data/services/file_selector_media_picker.dart';
import 'package:petit/common/data/services/folder_media_saver.dart';
import 'package:petit/common/data/services/gallery_media_saver.dart';
import 'package:petit/common/data/services/image_picker_media_picker.dart';
import 'package:petit/common/data/services/temp_workspace.dart';
import 'package:petit/common/domain/services/media_picker.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/common/domain/services/workspace.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/features/images/data/services/desktop_image_compressor.dart';
import 'package:petit/features/images/data/services/flutter_image_compressor.dart';
import 'package:petit/features/images/domain/services/image_compressor.dart';
import 'package:petit/features/images/domain/usecases/compress_images.dart';
import 'package:petit/features/images/domain/usecases/read_images.dart';
import 'package:petit/features/videos/data/services/ffmpeg_video_compressor.dart';
import 'package:petit/features/videos/data/services/ffmpeg_video_thumbnailer.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/services/video_thumbnailer.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {

  //Pref
  sl.registerSingleton<SharedPreferencesAsync>(
      SharedPreferencesAsync()
  );

  _registerMediaDependencies();
}

/// Platform services are registered here, so the ViewModels and use cases
/// only ever see the domain interfaces.
void _registerMediaDependencies() {
  if (PlatformInfo.isDesktop) {
    // Windows, macOS, Linux: OS file dialogs, a folder to save into, and an
    // image compressor that does not rely on mobile-only plugins.
    sl.registerLazySingleton<MediaPicker>(() => FileSelectorMediaPicker());
    sl.registerLazySingleton<MediaSaver>(() => FolderMediaSaver());
    sl.registerLazySingleton<ImageCompressor>(() => DesktopImageCompressor());
  } else {
    // Android and iOS (and the frozen web build, which never resolves these).
    sl.registerLazySingleton<MediaPicker>(() => ImagePickerMediaPicker());
    sl.registerLazySingleton<MediaSaver>(() => GalleryMediaSaver());
    sl.registerLazySingleton<ImageCompressor>(() => FlutterImageCompressor());
  }

  // Shared: FFmpeg Kit supports Android, iOS, macOS, Windows and Linux.
  sl.registerLazySingleton<Workspace>(() => TempWorkspace());
  sl.registerLazySingleton<VideoCompressor>(() => FfmpegVideoCompressor());
  sl.registerLazySingleton<VideoThumbnailer>(() => FfmpegVideoThumbnailer());

  // Use cases
  sl.registerLazySingleton<ReadImagesUseCase>(
      () => ReadImagesUseCase(sl<ImageCompressor>()));
  sl.registerLazySingleton<CompressImagesUseCase>(
      () => CompressImagesUseCase(sl<ImageCompressor>(), sl<MediaSaver>()));
  sl.registerLazySingleton<CompressVideoUseCase>(
      () => CompressVideoUseCase(sl<VideoCompressor>(), sl<MediaSaver>()));
}
