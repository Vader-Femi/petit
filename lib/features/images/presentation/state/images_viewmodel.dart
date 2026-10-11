import 'package:async/async.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/core/di/providers.dart';
import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/usecases/compress_images.dart';
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

  @override
  ImagesState build() => const ImagesState();

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
  }

  void updateGlobalQualitySlider(double value) {
    state = state.copyWith(globalQuality: (value * 100).toInt());
  }

  /// Switches "same quality for all images" on (at 50) or off.
  void setGlobalQualityEnabled(bool enabled) {
    state = state.copyWith(globalQuality: enabled ? 50 : null);
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

      state = state.copyWith(
        pickedImages: const [],
        currentImage: null,
        globalQuality: null,
      );

      final picked = await ref.read(readImagesUseCaseProvider)(paths);

      state = state.copyWith(
        pickedImages: picked,
        currentImage: picked[0],
        currentImageIndex: 0,
        loading: const LoadingData(isLoading: false),
      );
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
        state = state.copyWith(
          pickedImages: const [],
          currentImage: null,
          globalQuality: null,
        );

        final picked = await ref.read(readImagesUseCaseProvider)(paths);

        state = state.copyWith(
          pickedImages: picked,
          currentImage: picked[0],
          currentImageIndex: 0,
          loading: const LoadingData(isLoading: false),
        );
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

    final totalLength = state.pickedImages.length;

    final ImageBatchResult batch;
    try {
      batch = await ref.read(compressImagesUseCaseProvider)(
        images: List.of(state.pickedImages),
        globalQuality: state.globalQuality,
        isCancelled: () => completer.isCanceled,
        onProgress: (progress) => setLoading(
          LoadingData(
              isLoading: true,
              completedSteps: progress.completedSteps,
              totalSteps: progress.totalSteps,
              progressCounter: progress.percent),
        ),
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
        path: batch.destinationLabel);
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
