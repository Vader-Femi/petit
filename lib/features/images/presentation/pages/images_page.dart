import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:petit/common/widgets/compression_progress_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/core/utils/adaptive.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/core/utils/shortcut_labels.dart';
import 'package:petit/features/images/presentation/state/images_state.dart';
import 'package:petit/features/images/presentation/state/loading_data.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:petit/features/images/presentation/widget/image_options_panel.dart';
import '../../../../common/widgets/compression_summary_dialog.dart';
import '../../../../common/widgets/save_to_tile.dart';
import '../../../../common/widgets/slider_box.dart';

class ImagesPage extends ConsumerStatefulWidget {
  const ImagesPage({super.key});

  @override
  ConsumerState<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends ConsumerState<ImagesPage> {
  // Adjust to actual height of your FAB + margin
  static const fabHeight = 72.0;

  /// The image carousel, with previous/next buttons on desktop (dragging with
  /// a mouse is not obvious there).
  Widget _buildCarousel(ImagesState state, ImagesViewModel viewModel) {
    final count = state.pickedImages.length;
    final currentIndex = state.currentImageIndex ?? 0;
    final showArrows = PlatformInfo.isDesktop && count > 1;

    // StackFit.expand keeps the carousel's constraints tight, as they were
    // when it sat directly inside an Expanded.
    return Stack(
      fit: StackFit.expand,
      children: [
        CarouselSlider(
          items: state.pickedImages.map((imageData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                // A converted copy for formats Flutter cannot draw (HEIC).
                imageData.previewFile ?? imageData.imageFile,
                frameBuilder: (BuildContext context, Widget child, int? frame,
                    bool? wasSynchronouslyLoaded) {
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: Duration(milliseconds: 200),
                    curve: Curves.easeIn,
                    child: child,
                  );
                },
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                // Flutter cannot decode every format on every
                // platform (e.g. HEIC on desktop).
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 48),
                      SizedBox(height: 8),
                      Text('Preview not available'),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
          carouselController: ref.read(carouselControllerProvider),
          options: CarouselOptions(
              autoPlay: false,
              enlargeStrategy: CenterPageEnlargeStrategy.zoom,
              enlargeCenterPage: true,
              pageSnapping: true,
              scrollDirection: Axis.horizontal,
              pauseAutoPlayOnTouch: true,
              enableInfiniteScroll: false,
              onPageChanged: (index, _) =>
                  viewModel.updateCurrentImageAndIndex(index),
              reverse: false),
        ),
        if (showArrows)
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filledTonal(
                tooltip: 'Previous image (\u2190)',
                onPressed: currentIndex > 0 ? viewModel.previousImage : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ),
          ),
        if (showArrows)
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filledTonal(
                tooltip: 'Next image (\u2192)',
                onPressed:
                    currentIndex < count - 1 ? viewModel.nextImage : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ),
          ),
      ],
    );
  }

  /// "Image 3 of 8": the image being worked on out of the whole batch.
  static String _stepLabel(LoadingData loading) {
    final total = loading.totalSteps ?? 1;
    final current = ((loading.completedSteps ?? 0) + 1).clamp(1, total);
    return total == 1 ? 'Working on your image' : 'Image $current of $total';
  }

  /// "2 of 5", the quality slider and the options under it.
  List<Widget> _buildControls(
    BuildContext context,
    ImagesState state,
    ImagesViewModel viewModel,
  ) {
    final currentImage = state.currentImage;

    return [
      // Current image index
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          "${(state.currentImageIndex ?? -1) + 1} of ${state.pickedImages.length}",
          style: const TextStyle(fontSize: 16),
        ),
      ),

      const SizedBox(height: 10),

      if (currentImage != null)
        buildSliderBox(
          context: context,
          label: "Image Quality",
          minValue: "Compressed",
          maxValue: "Original Quality",
          tootTipMessage: "Adjust image quality.\n"
              "•Compressed = less clarity, smaller size\n"
              "•Original = same clarity, same size\n"
              "•Middle = same clarity, smaller size\n"
              "•Recommended = Between 20% - 98%",
          slider: Slider(
            value: ((state.globalQuality ?? currentImage.quality) / 100)
                .clamp(0.0, 1.0),
            min: 0,
            max: 1,
            divisions: 99,
            label: "${(state.globalQuality ?? currentImage.quality).round()}%",
            onChanged: (value) {
              if (state.globalQuality != null) {
                viewModel.updateGlobalQualitySlider(value);
              } else {
                viewModel.updateCurrentImageQuality(value);
              }
            },
          ),
          showGlobalSwitch: state.pickedImages.length > 1,
          isGlobal: state.globalQuality != null,
          onGlobalToggle: viewModel.setGlobalQualityEnabled,
        ),

      // Expected size, transparency and location switches.
      const ImageOptionsPanel(),

      // Desktop only: where the results are saved.
      const SaveToTile(),
    ];
  }

  Widget _buildBody(
    BuildContext context,
    ImagesState state,
    ImagesViewModel viewModel,
  ) {
    final loading = state.loading;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        state.pickedImages.isEmpty
            ? Center(
                child: Text(
                  PlatformInfo.isDesktop
                      ? "Add images and start compressing\nor drop them anywhere in this window"
                      : "Add images and start compressing",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 15),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final controls = _buildControls(context, state, viewModel);

                    // Wide: preview on the left, controls on the right.
                    if (constraints.maxWidth >= kTwoPaneMinWidth) {
                      return Row(
                        children: [
                          Expanded(child: _buildCarousel(state, viewModel)),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: kControlsPaneWidth,
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...controls,
                                    // Reserve space for FABs
                                    const SizedBox(height: fabHeight),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Narrow: stacked, as on a phone.
                    return Column(
                      children: [
                        Expanded(child: _buildCarousel(state, viewModel)),
                        const SizedBox(height: 10),
                        ...controls,
                        // Reserve space for FABs
                        const SizedBox(height: fabHeight),
                      ],
                    );
                  },
                ),
              ),
        if (loading.isLoading)
          if (loading.totalSteps == null)
            const CompressionProgressView(title: 'Loading images')
          else
            CompressionProgressView(
              title: 'Compressing images',
              percent: loading.progressCounter,
              detail: _stepLabel(loading),
              eta: loading.eta,
              // One or two images are over too quickly for a countdown.
              showEta: loading.totalSteps! > 2,
              keepOpenHint: true,
            ),
      ],
    );
  }

  Widget _buildFab(
    BuildContext context,
    ImagesState state,
    ImagesViewModel viewModel,
  ) {
    if (state.pickedImages.isEmpty) {
      return FloatingActionButton(
        onPressed: () async => viewModel.pickImages(),
        tooltip: withShortcut("Add Images", "O"),
        child: const Icon(Icons.add_photo_alternate_outlined),
      );
    }

    if (state.loading.isLoading) {
      return FloatingActionButton.extended(
        icon: const Icon(Icons.clear),
        tooltip: withShortcut("Cancel compression", "Esc", withModifier: false),
        onPressed: () async => viewModel.requestCancel(),
        label: const Text('Cancel'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (state.isFabOpen) ...[
              FloatingActionButton.extended(
                icon: const Icon(Icons.compress_outlined),
                tooltip: withShortcut("Compress Images", "Enter"),
                onPressed: () async {
                  viewModel.startCompression(onComplete: (summaryReport) {
                    if (mounted) {
                      showCompressionSummaryDialog(
                          context: context, summaryReport: summaryReport);
                    }
                  });
                },
                label: const Text('Compress'),
              ),
              SizedBox(width: 10),
              FloatingActionButton.extended(
                icon: const Icon(Icons.delete_outline),
                tooltip:
                    withShortcut("Remove images", "Del", withModifier: false),
                onPressed: () async {
                  viewModel.clearPickedImages();
                },
                label: const Text('Clear'),
              ),
            ],
            const SizedBox(width: 10),
            FloatingActionButton(
              heroTag: "toggle_fab",
              onPressed: viewModel.toggleFab,
              tooltip: state.isFabOpen ? "Close Actions" : "Show Actions",
              child: Icon(
                  state.isFabOpen ? Icons.close : Icons.compress_outlined),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imagesViewModelProvider);
    final viewModel = ref.read(imagesViewModelProvider.notifier);

    // Show one-shot messages as snackbars, then clear them.
    ref.listen<String?>(
      imagesViewModelProvider.select((s) => s.result),
      (previous, message) {
        if (message == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
          viewModel.clearResult();
        });
      },
    );

    return Scaffold(
      body: _buildBody(context, state, viewModel),
      floatingActionButton: _buildFab(context, state, viewModel),
    );
  }
}
