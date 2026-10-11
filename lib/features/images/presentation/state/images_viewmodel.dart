import 'package:async/async.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_picker.dart';
import 'package:petit/common/domain/services/workspace.dart';
import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/usecases/compress_images.dart';
import 'package:petit/features/images/domain/usecases/read_images.dart';
import 'package:petit/service_locator.dart';
import 'package:share_handler/share_handler.dart';
import '../../data/loading_data.dart';
import '../../../../common/data/summary_report.dart';

ImagesViewModel get getImagesViewModel => Super.init(ImagesViewModel());

/// UI state for the image tab. Picking, reading, compressing and saving live
/// in the domain use cases; this class only holds state and reacts to them.
class ImagesViewModel {
  final result = RxT<String?>(null);
  final isLoading = RxT<LoadingData>(LoadingData(isLoading: false));
  final pickedImages = RxList<ImageData>([]);
  final currentImage = RxT<ImageData?>(null);
  final currentImageIndex = RxT<int?>(null);
  final globalQualitySlider = RxT<int?>(null);
  final isFabOpen = RxT<bool>(true);

  CancelableCompleter<void> completer = CancelableCompleter();

  /// Owned here (not by the page) so keyboard shortcuts can move the carousel.
  final carouselController = CarouselSliderController();

  /// True while images are being read or compressed.
  bool get isBusy => isLoading.state.isLoading;

  // Resolved lazily: `getImagesViewModel` constructs a new instance on every
  // access, so nothing may be looked up in the constructor.
  late final MediaPicker _picker = sl<MediaPicker>();
  late final Workspace _workspace = sl<Workspace>();
  late final ReadImagesUseCase _readImages = sl<ReadImagesUseCase>();
  late final CompressImagesUseCase _compressImages =
      sl<CompressImagesUseCase>();

  void setIsLoading(LoadingData loadingData) {
    isLoading.state = loadingData;
  }

  Future<void> showResult(String? result) async {
    this.result.state = result;
  }

  Future<void> updateCurrentImageAndIndex(int index) async {
    final image = pickedImages.state.elementAt(index);
    currentImage.state = image;
    currentImageIndex.state = index;
  }

  void updateCurrentImageQuality(double value) {
    if (currentImage.state != null) {
      final currentImageIndex =
          pickedImages.state.indexOf(currentImage.state!, 0);

      final newImageData =
          currentImage.state!.copyWith(quality: (value * 100).toInt());
      pickedImages.state[currentImageIndex] = newImageData;
      currentImage.state = newImageData;

      if (globalQualitySlider.state != null) {
        globalQualitySlider.state = null;
      }
    }
  }

  void updateGlobalQualitySlider(double value) {
    globalQualitySlider.state = (value * 100).toInt();
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
    if (isLoading.state.isLoading) return;

    try {
      setIsLoading(
        LoadingData(
            isLoading: true,
            completedSteps: null,
            totalSteps: null,
            progressCounter: null),
      );

      pickedImages.state = [];
      currentImage.state = null;
      globalQualitySlider.state = null;

      final picked = await _readImages(paths);

      pickedImages.state = picked;
      currentImage.state = picked[0];
      currentImageIndex.state = 0;
      setIsLoading(LoadingData(isLoading: false));
    } catch (e) {
      await showResult("An error ocurred - ${e.toString()}");
      setIsLoading(LoadingData(isLoading: false));
    }
  }

  Future<void> pickMultipleImages() async {
    try {
      setIsLoading(
        LoadingData(
            isLoading: true,
            completedSteps: null,
            totalSteps: null,
            progressCounter: null),
      );

      final paths = await _picker.pickImages();

      if (paths.isNotEmpty) {
        pickedImages.state = [];
        currentImage.state = null;
        globalQualitySlider.state = null;

        final picked = await _readImages(paths);

        pickedImages.state = picked;
        currentImage.state = picked[0];
        currentImageIndex.state = 0;
        setIsLoading(LoadingData(isLoading: false));
      } else {
        await showResult("No file picked!");
        setIsLoading(LoadingData(isLoading: false));
        return;
      }
    } catch (e) {
      await showResult("An error ocurred - ${e.toString()}");
      setIsLoading(LoadingData(isLoading: false));
    }
  }

  Future<SummaryReport?> compressAllSelectedImages() async {
    if (!isLoading.state.isLoading) {
      if (pickedImages.isEmpty) {
        await showResult("Select images first");
        return null;
      }

      final totalLength = pickedImages.state.length;

      final ImageBatchResult batch;
      try {
        batch = await _compressImages(
          images: List.of(pickedImages.state),
          globalQuality: globalQualitySlider.state,
          isCancelled: () => completer.isCanceled == true,
          onProgress: (progress) => setIsLoading(
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
        await showResult(e.message);
        return null;
      }

      currentImage.state = null;
      currentImageIndex.state = 0;
      globalQualitySlider.state = null;

      await _workspace.clear();

      pickedImages.state = [];

      setIsLoading(
        LoadingData(
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
    return null;
  }

  /// Starts compressing every picked image. [onComplete] receives the summary
  /// unless the job was cancelled or could not start.
  void startCompression({required void Function(SummaryReport summary) onComplete}) {
    completer = CancelableCompleter(onCancel: cancelCompressingAllImages);

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

  Future<void> previousImage() => _moveCarousel(forward: false);

  Future<void> nextImage() => _moveCarousel(forward: true);

  Future<void> _moveCarousel({required bool forward}) async {
    if (pickedImages.state.length < 2) return;
    const duration = Duration(milliseconds: 250);
    try {
      if (forward) {
        await carouselController.nextPage(duration: duration, curve: Curves.easeOut);
      } else {
        await carouselController.previousPage(duration: duration, curve: Curves.easeOut);
      }
    } catch (e) {
      debugPrint('Could not move the carousel: $e');
    }
  }

  String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    final i = (bytes == 0) ? 0 : (bytes.bitLength / 10).floor();
    final size = bytes / (1 << (10 * i));
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Future<void> selectImageButtonUseCase() async {
    if (!isLoading.state.isLoading) {
      await pickMultipleImages();
    }
  }

  void cancelCompressingAllImages() {
    final totalLength = pickedImages.state.length;

    currentImage.state = null;
    currentImageIndex.state = 0;
    globalQualitySlider.state = null;
    pickedImages.state = [];

    setIsLoading(
      LoadingData(
          progressCounter: 100,
          isLoading: false,
          completedSteps: totalLength,
          totalSteps: totalLength),
    );
  }
}
