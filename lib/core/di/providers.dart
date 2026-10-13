import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/common/domain/services/folder_picker.dart';
import 'package:petit/common/domain/services/media_picker.dart';
import 'package:petit/common/domain/services/output_folder_preference.dart';
import 'package:petit/common/domain/services/workspace.dart';
import 'package:petit/features/images/domain/usecases/compress_images.dart';
import 'package:petit/features/images/domain/usecases/estimate_image_size.dart';
import 'package:petit/features/images/domain/usecases/read_images.dart';
import 'package:petit/features/settings/domain/entities/app_settings.dart';
import 'package:petit/features/settings/domain/services/settings_repository.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/usecases/compress_video.dart';
import 'package:petit/features/videos/presentation/preview/video_preview.dart';
import 'package:petit/features/videos/presentation/preview/video_preview_factory.dart';
import 'package:petit/service_locator.dart';

// get_it still wires the platform implementations (see service_locator.dart).
// These providers hand them to the ViewModels, and let tests replace them
// with fakes: `ProviderContainer.test(overrides: [mediaPickerProvider.overrideWithValue(fake)])`.

final mediaPickerProvider = Provider<MediaPicker>((ref) => sl<MediaPicker>());

final workspaceProvider = Provider<Workspace>((ref) => sl<Workspace>());

final folderPickerProvider =
    Provider<FolderPicker>((ref) => sl<FolderPicker>());

final outputFolderPreferenceProvider = Provider<OutputFolderPreference>(
    (ref) => sl<OutputFolderPreference>());

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => sl<SettingsRepository>());

/// The settings read from disk before the app started (the defaults if that
/// failed). The Settings ViewModel starts from this.
final initialSettingsProvider = Provider<AppSettings>(
    (ref) => sl.isRegistered<AppSettings>() ? sl<AppSettings>() : const AppSettings());

final readImagesUseCaseProvider =
    Provider<ReadImagesUseCase>((ref) => sl<ReadImagesUseCase>());

final compressImagesUseCaseProvider =
    Provider<CompressImagesUseCase>((ref) => sl<CompressImagesUseCase>());

final estimateImageSizeUseCaseProvider = Provider<EstimateImageSizeUseCase>(
    (ref) => sl<EstimateImageSizeUseCase>());

final videoCompressorProvider =
    Provider<VideoCompressor>((ref) => sl<VideoCompressor>());

final compressVideoUseCaseProvider =
    Provider<CompressVideoUseCase>((ref) => sl<CompressVideoUseCase>());

/// Creates the preview for a picked video (playback or still frame).
final videoPreviewFactoryProvider =
    Provider<VideoPreview Function(File file)>((ref) => createVideoPreview);
