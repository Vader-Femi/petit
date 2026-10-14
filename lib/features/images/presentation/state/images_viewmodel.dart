import 'dart:async';

import 'package:async/async.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/di/providers.dart';
import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/common/domain/progress_eta.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/entities/image_size_estimate.dart';
import 'package:petit/features/images/domain/usecases/compress_images.dart';
import 'package:petit/features/settings/presentation/state/settings_viewmodel.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';
import 'package:share_handler/share_handler.dart';
import 'images_state.dart';
import 'loading_data.dart';

final imagesViewModelProvider =
    NotifierProvider<ImagesViewModel, ImagesState>(ImagesViewModel.new);

/// Lives in its own provider so keyboard shortcuts and the page share one
/// controller without storing it in the ViewModel.
final carouselControllerProvider =
    Provider<CarouselSliderController>((ref) => CarouselSliderController());

/// ViewModel of the Images tab. Picking, reading, compressing and saving live
/// in the domain use cases; this class only holds state and reacts to them.
class ImagesViewModel extends Notifier<ImagesState> {
  /// Handle of the running batch, replaced for every job. It is never
  /// rebuilt by Riverpod because [build] watches nothing.
  CancelableCompleter<void> completer = CancelableCompleter();

  /// Waits for the sliders to settle before the (real) test compression runs.
  static const _estimateDelay = Duration(milliseconds: 500);

  Timer? _estimateTimer;

  /// Bumped whenever an estimate in flight stops being wanted, so a late
  /// result is ignored instead of shown for the wrong settings.
  int _estimateGeneration = 0;

  /// Estimates already worked out, so going back to a setting is instant.
  final Map<String, ImageSizeEstimate> _estimateCache = {};

  @override
  ImagesState build() {
    ref.onDispose(() => _estimateTimer?.cancel());

    // Changing the defaults in Settings applies at once while nothing is
    // picked; a selection in progress keeps the settings it was started with.
    ref.listen(settingsViewModelProvider, (_, settings) {
      if (state.pickedImages.isEmpty && !state.isBusy) {
        state = state.copyWith(options: settings.imageOptions);
      }
    });

    return ImagesState(
        options: ref.read(settingsViewModelProvider).imageOptions);
  }

  /// True while images are being read or compressed.
  bool get isBusy => state.isBusy;

  void setLoading(LoadingData loading) {
    state = state.copyWith(loading: loading);
  }

  void showResult(String? message) {
    state = state.copyWith(result: message);
  }

  void clearResult() => showResult(null);

  void toggleFab() {
    state = state.copyWith(isFabOpen: !state.isFabOpen);
  }

  void updateCurrentImageAndIndex(int index) {
    final images = state.pickedImages;
    if (index < 0 || index >= images.length) return;
    state = state.copyWith(currentImage: images[index], currentImageIndex: index);
    _scheduleEstimate();
  }

  void updateCurrentImageQuality(double value) {
    final current = state.currentImage;
    if (current == null) return;

    final index = state.pickedImages.indexOf(current);
    if (index < 0) return;

    final updated = current.copyWith(quality: (value * 100).toInt());
    final images = List<ImageData>.of(state.pickedImages)..[index] = updated;

    // Editing one image's quality turns the shared quality off.
    state = state.copyWith(
      pickedImages: images,
      currentImage: updated,
      globalQuality: null,
    );
    _scheduleEstimate();
  }

  void updateGlobalQualitySlider(double value) {
    state = state.copyWith(globalQuality: (value * 100).toInt());
    _scheduleEstimate();
  }

  /// Switches "same quality for all images" on (at 50) or off.
  void setGlobalQualityEnabled(bool enabled) {
    state = state.copyWith(globalQuality: enabled ? 50 : null);
    _scheduleEstimate();
  }

  /// Keep transparent PNG/WebP images transparent (or flatten them to JPEG).
  void setKeepTransparency(bool keep) {
    state = state.copyWith(
        options: state.options.copyWith(keepTransparency: keep));
    _scheduleEstimate();
  }

  /// Remove the location (and other metadata) from the compressed images.
  void setRemoveLocation(bool remove) {
    state =
        state.copyWith(options: state.options.copyWith(removeLocation: remove));
    _scheduleEstimate();
  }

  /// Works out, after a short pause, how big the current image would be with
  /// the current settings. Does nothing useful while a job is running (the
  /// real compression must not compete with test compressions).
  void _scheduleEstimate() {
    _estimateTimer?.cancel();
    final generation = ++_estimateGeneration;

    final image = state.currentImage;
    if (image == null || state.isBusy) {
      state = state.copyWith(estimate: null, isEstimating: false);
      return;
    }

    final quality = state.globalQuality ?? image.quality;
    final options = state.options;
    final key = '${image.imageFile.path}|$quality|'
        '${options.keepTransparency}|${options.removeLocation}';

    final cached = _estimateCache[key];
    if (cached != null) {
      state = state.copyWith(estimate: cached, isEstimating: false);
      return;
    }

    state = state.copyWith(estimate: null, isEstimating: true);

    _estimateTimer = Timer(_estimateDelay, () async {
      ImageSizeEstimate? result;
      try {
        result = await ref.read(estimateImageSizeUseCaseProvider)(
          image,
          quality: quality,
          options: options,
        );
      } catch (e) {
        // The estimate is a convenience: if it fails, the real job reports
        // the problem.
        debugPrint('Could not estimate the size: $e');
      }

      if (generation != _estimateGeneration) return;
      if (result != null) _estimateCache[key] = result;
      state = state.copyWith(estimate: result, isEstimating: false);
    });
  }

  /// Forgets any estimate and stops one in progress.
  void _cancelEstimate() {
    _estimateTimer?.cancel();
    _estimateGeneration++;
    state = state.copyWith(estimate: null, isEstimating: false);
  }

  Future<void> addSharedImages([List<SharedAttachment>? sharedFiles]) async {
    if (sharedFiles != null && sharedFiles.isNotEmpty) {
      await addImagePaths(sharedFiles.map((file) => file.path).toList());
    }
  }

  /// Replaces the current selection with the images at [paths] (shared into
  /// the app, or dropped onto the window).
  Future<void> addImagePaths(List<String> paths) async {
    if (paths.isEmpty) return;
    if (state.isBusy) return;

    try {
      setLoading(const LoadingData(isLoading: true));

      _estimateCache.clear();
      final defaults = ref.read(settingsViewModelProvider);
      state = state.copyWith(
        pickedImages: const [],
        currentImage: null,
        globalQuality: null,
        options: defaults.imageOptions,
      );

      final picked = await ref.read(readImagesUseCaseProvider)(paths,
          quality: defaults.imageQuality);

      state = state.copyWith(
        pickedImages: picked,
        currentImage: picked[0],
        currentImageIndex: 0,
        loading: const LoadingData(isLoading: false),
      );
      _scheduleEstimate();
    } catch (e) {
      state = state.copyWith(
        result: "An error ocurred - ${e.toString()}",
        loading: const LoadingData(isLoading: false),
      );
    }
  }

  Future<void> pickImages() async {
    if (state.isBusy) return;

    try {
      setLoading(const LoadingData(isLoading: true));

      final paths = await ref.read(mediaPickerProvider).pickImages();

      if (paths.isNotEmpty) {
        _estimateCache.clear();
        final defaults = ref.read(settingsViewModelProvider);
        state = state.copyWith(
          pickedImages: const [],
          currentImage: null,
          globalQuality: null,
          options: defaults.imageOptions,
        );

        final picked = await ref.read(readImagesUseCaseProvider)(paths,
            quality: defaults.imageQuality);

        state = state.copyWith(
          pickedImages: picked,
          currentImage: picked[0],
          currentImageIndex: 0,
          loading: const LoadingData(isLoading: false),
        );
        _scheduleEstimate();
      } else {
        state = state.copyWith(
          result: "No file picked!",
          loading: const LoadingData(isLoading: false),
        );
      }
    } catch (e) {
      state = state.copyWith(
        result: "An error ocurred - ${e.toString()}",
        loading: const LoadingData(isLoading: false),
      );
    }
  }

  Future<SummaryReport?> compressAllSelectedImages() async {
    if (state.isBusy) return null;

    if (state.pickedImages.isEmpty) {
      showResult("Select images first");
      return null;
    }

    // Both tabs share one work folder, which a finishing job empties.
    if (ref.read(videosViewModelProvider).isBusy) {
      showResult("Wait for the video to finish first");
      return null;
    }

    _cancelEstimate();

    final totalLength = state.pickedImages.length;

    final eta = ProgressEta()..start();

    final ImageBatchResult batch;
    try {
      batch = await ref.read(compressImagesUseCaseProvider)(
        images: List.of(state.pickedImages),
        globalQuality: state.globalQuality,
        options: state.options,
        isCancelled: () => completer.isCanceled,
        onProgress: (progress) {
          eta.update(progress.completedSteps / progress.totalSteps);
          setLoading(LoadingData(
              isLoading: true,
              completedSteps: progress.completedSteps,
              totalSteps: progress.totalSteps,
              progressCounter: progress.percent,
              eta: eta.remaining));
        },
        onError: showResult,
      );
    } on MediaException catch (e) {
      // e.g. the user closed the folder dialog on desktop.
      showResult(e.message);
      return null;
    }

    state = state.copyWith(
      currentImage: null,
      currentImageIndex: 0,
      globalQuality: null,
    );

    await ref.read(workspaceProvider).clear();

    state = state.copyWith(
      pickedImages: const [],
      loading: LoadingData(
          progressCounter: 100,
          isLoading: false,
          completedSteps: totalLength,
          totalSteps: totalLength),
    );

    return SummaryReport(
        originalSizeBytes: formatBytes(batch.originalBytes),
        compressedSizeBytes: formatBytes(batch.compressedBytes),
        savedBytes: formatBytes(batch.savedBytes),
        savedPercent: batch.savedFraction,
        path: batch.destinationLabel,
        folderPath: batch.destinationFolder);
  }

  /// Starts compressing every picked image. [onComplete] receives the summary
  /// unless the job was cancelled or could not start.
  void startCompression(
      {required void Function(SummaryReport summary) onComplete}) {
    completer = CancelableCompleter(onCancel: clearPickedImages);

    completer.complete(compressAllSelectedImages().then((summaryReport) {
      if (summaryReport != null) onComplete(summaryReport);
    }));
  }

  /// Asks a running compression to stop.
  void requestCancel() {
    try {
      if (!completer.isCanceled || !completer.isCompleted) {
        completer.operation.cancel();
      }
      showResult("Cancelling");
    } catch (e) {
      debugPrint('Error during cancel: $e');
    }
  }

  /// Drops the selection (the "Clear" button, tab switches, and a cancelled job).
  void clearPickedImages() {
    final totalLength = state.pickedImages.length;
    _estimateCache.clear();
    _cancelEstimate();

    state = state.copyWith(
      pickedImages: const [],
      currentImage: null,
      currentImageIndex: 0,
      globalQuality: null,
      loading: LoadingData(
          progressCounter: 100,
          isLoading: false,
          completedSteps: totalLength,
          totalSteps: totalLength),
    );
  }

  Future<void> previousImage() => _moveCarousel(forward: false);

  Future<void> nextImage() => _moveCarousel(forward: true);

  Future<void> _moveCarousel({required bool forward}) async {
    if (state.pickedImages.length < 2) return;

    final controller = ref.read(carouselControllerProvider);
    const duration = Duration(milliseconds: 250);
    try {
      if (forward) {
        await controller.nextPage(duration: duration, curve: Curves.easeOut);
      } else {
        await controller.previousPage(
            duration: duration, curve: Curves.easeOut);
      }
    } catch (e) {
      debugPrint('Could not move the carousel: $e');
    }
  }
}
