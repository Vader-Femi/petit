import 'package:petit/features/images/domain/entities/image_data.dart';
import 'package:petit/features/images/domain/entities/image_options.dart';
import 'package:petit/features/images/domain/entities/image_size_estimate.dart';
import 'package:petit/features/images/presentation/state/loading_data.dart';

const Object _unset = Object();

/// Everything the Images tab shows. Immutable: change it with [copyWith].
class ImagesState {
  const ImagesState({
    this.pickedImages = const [],
    this.currentImage,
    this.currentImageIndex,
    this.globalQuality,
    this.loading = const LoadingData(isLoading: false),
    this.result,
    this.isFabOpen = true,
    this.options = const ImageOptions(),
    this.estimate,
    this.isEstimating = false,
  });

  final List<ImageData> pickedImages;
  final ImageData? currentImage;
  final int? currentImageIndex;

  /// Quality (0..100) used for every image, or null when each image has its own.
  final int? globalQuality;
  final LoadingData loading;

  /// One-shot message for a snackbar; the page clears it once shown.
  final String? result;
  final bool isFabOpen;

  /// Transparency and metadata choices for the whole job.
  final ImageOptions options;

  /// Size the current image would have with the current settings, once worked
  /// out. Null while [isEstimating] or when it could not be worked out.
  final ImageSizeEstimate? estimate;
  final bool isEstimating;

  /// True while images are being read or compressed.
  bool get isBusy => loading.isLoading;

  /// Nullable fields can be set to null by passing null explicitly.
  ImagesState copyWith({
    List<ImageData>? pickedImages,
    Object? currentImage = _unset,
    Object? currentImageIndex = _unset,
    Object? globalQuality = _unset,
    LoadingData? loading,
    Object? result = _unset,
    bool? isFabOpen,
    ImageOptions? options,
    Object? estimate = _unset,
    bool? isEstimating,
  }) {
    return ImagesState(
      pickedImages: pickedImages ?? this.pickedImages,
      currentImage: identical(currentImage, _unset)
          ? this.currentImage
          : currentImage as ImageData?,
      currentImageIndex: identical(currentImageIndex, _unset)
          ? this.currentImageIndex
          : currentImageIndex as int?,
      globalQuality: identical(globalQuality, _unset)
          ? this.globalQuality
          : globalQuality as int?,
      loading: loading ?? this.loading,
      result: identical(result, _unset) ? this.result : result as String?,
      isFabOpen: isFabOpen ?? this.isFabOpen,
      options: options ?? this.options,
      estimate: identical(estimate, _unset)
          ? this.estimate
          : estimate as ImageSizeEstimate?,
      isEstimating: isEstimating ?? this.isEstimating,
    );
  }
}
