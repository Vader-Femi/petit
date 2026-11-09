import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:petit/common/widgets/compression_progress_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/core/utils/adaptive.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/core/utils/shortcut_labels.dart';
import 'package:petit/features/videos/presentation/preview/video_preview.dart';
import 'package:petit/features/videos/presentation/state/videos_state.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';
import 'package:petit/features/videos/presentation/widget/video_options_panel.dart';
import '../../../../common/widgets/compression_summary_dialog.dart';

class VideosPage extends ConsumerStatefulWidget {
  const VideosPage({super.key});

  @override
  ConsumerState<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends ConsumerState<VideosPage> {
  // Adjust to actual height of your FAB + margin
  static const fabHeight = 72.0;
  final CarouselSliderController _carouselController =
      CarouselSliderController();

  Widget _buildCarousel(
    BuildContext context,
    VideosState state,
    VideosViewModel viewModel,
    VideoPreview? preview,
  ) {
    final count = state.pickedVideos.length;
    final currentIndex = state.currentVideoIndex;
    final showArrows = PlatformInfo.isDesktop && count > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        CarouselSlider(
          items: state.pickedVideos.asMap().entries.map((entry) {
            final index = entry.key;
            final video = entry.value;
            final isCurrent = index == currentIndex;

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isCurrent && preview != null && preview.isInitialized
                  ? AspectRatio(
                      aspectRatio: preview.aspectRatio,
                      child: preview.build(context),
                    )
                  : (video.thumbnailFile != null
                      ? Image.file(
                          video.thumbnailFile!,
                          fit: BoxFit.contain,
                        )
                      : Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.movie_outlined, size: 48),
                                  const SizedBox(height: 8),
                                  Text(
                                    video.videoFile.path
                                        .split(Platform.pathSeparator)
                                        .last,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
            );
          }).toList(),
          carouselController: _carouselController,
          options: CarouselOptions(
            autoPlay: false,
            enlargeStrategy: CenterPageEnlargeStrategy.zoom,
            enlargeCenterPage: true,
            pageSnapping: true,
            scrollDirection: Axis.horizontal,
            enableInfiniteScroll: false,
            onPageChanged: (index, _) =>
                viewModel.updateCurrentVideoIndex(index),
          ),
        ),
        if (showArrows)
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton.filledTonal(
                tooltip: 'Previous video (\u2190)',
                onPressed: currentIndex > 0
                    ? () {
                        _carouselController.previousPage();
                        viewModel.previousVideo();
                      }
                    : null,
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
                tooltip: 'Next video (\u2192)',
                onPressed: currentIndex < count - 1
                    ? () {
                        _carouselController.nextPage();
                        viewModel.nextVideo();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    VideosState state,
    VideosViewModel viewModel,
  ) {
    final preview = state.preview;
    final hasContent = state.pickedVideos.isNotEmpty ||
        (preview != null && preview.isInitialized);

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        if (hasContent)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 15),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final Widget previewBox;
                if (state.pickedVideos.length > 1) {
                  previewBox = _buildCarousel(context, state, viewModel, preview);
                } else if (preview != null && preview.isInitialized) {
                  previewBox = ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: preview.aspectRatio,
                      child: preview.build(context),
                    ),
                  );
                } else {
                  previewBox = const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // Wide: preview on the left, sliders on the right.
                if (constraints.maxWidth >= kTwoPaneMinWidth) {
                  return Row(
                    children: [
                      Expanded(child: Center(child: previewBox)),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: kControlsPaneWidth,
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (state.pickedVideos.length > 1) ...[
                                  Text(
                                    "${state.currentVideoIndex + 1} of ${state.pickedVideos.length}",
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                                const VideoOptionsPanel(),
                                // Space for FABs
                                const SizedBox(height: fabHeight),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Narrow: stacked, as on a phone. There are many options, so
                // the whole column scrolls instead of squeezing the preview.
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: constraints.maxHeight * 0.45),
                        child: previewBox,
                      ),
                      const SizedBox(height: 12),
                      if (state.pickedVideos.length > 1) ...[
                        Text(
                          "${state.currentVideoIndex + 1} of ${state.pickedVideos.length}",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                      ],
                      const VideoOptionsPanel(),
                      // Space for FABs
                      const SizedBox(height: fabHeight),
                    ],
                  ),
                );
              },
            ),
          )
        else
          Center(
            child: Text(
              PlatformInfo.isDesktop
                  ? "Add videos and start compressing\nor drop them anywhere in this window"
                  : "Add videos and start compressing",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
          ),
        if (state.isCompressing)
          CompressionProgressView(
            title: state.isBatch ? 'Compressing videos' : 'Compressing video',
            detail: state.isBatch
                ? 'Video ${state.completedVideos + 1} of ${state.totalVideos}'
                : null,
            percent: state.percentComplete,
            eta: state.eta,
            showEta: true,
            keepOpenHint: true,
          )
        else if (state.isLoading)
          CompressionProgressView(
            title: state.isBatch ? 'Loading videos' : 'Loading video',
          ),
      ],
    );
  }

  Widget _buildFab(
    BuildContext context,
    VideosState state,
    VideosViewModel viewModel,
  ) {
    if (state.videoFile == null && state.pickedVideos.isEmpty) {
      return FloatingActionButton(
        onPressed: () async {
          await viewModel.pickVideo();
        },
        tooltip: withShortcut("Pick videos", "O"),
        child: const Icon(Icons.video_library),
      );
    }

    if (state.isCompressing) {
      if (state.currentJob != null) {
        return FloatingActionButton.extended(
          icon: const Icon(Icons.clear),
          tooltip:
              withShortcut("Cancel compression", "Esc", withModifier: false),
          onPressed: () async {
            try {
              viewModel.cancelCompressingVideo();
            } catch (e) {
              debugPrint('Error during cancel: $e');
            }
          },
          label: const Text('Cancel'),
        );
      }
      return Container();
    }

    final preview = state.preview;
    final canPlay = preview != null && preview.isInitialized && preview.canPlay;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (state.isFabOpen) ...[
              const SizedBox(width: 30),
              canPlay
                  ? FloatingActionButton(
                      onPressed: () {
                        // Playing is not part of the ViewModel state.
                        setState(() {
                          preview.togglePlayback();
                        });
                      },
                      child: Icon(
                        preview.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    )
                  : Container(),
              const SizedBox(width: 10),
              FloatingActionButton.extended(
                icon: const Icon(Icons.delete_outline),
                tooltip: withShortcut(
                    state.isBatch ? "Remove videos" : "Remove video",
                    "Del",
                    withModifier: false),
                onPressed: () async {
                  viewModel.removeVideo();
                },
                label: Text(state.isBatch ? 'Remove videos' : 'Remove video'),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.extended(
                icon: const Icon(Icons.compress_outlined),
                tooltip: withShortcut(
                    state.isBatch ? "Compress Videos" : "Compress Video",
                    "Enter"),
                onPressed: () async {
                  await viewModel.compressVideo(onComplete: (summaryReport) {
                    if (mounted) {
                      showCompressionSummaryDialog(
                          context: context, summaryReport: summaryReport);
                    }
                  });
                },
                label: const Text('Compress'),
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
    final state = ref.watch(videosViewModelProvider);
    final viewModel = ref.read(videosViewModelProvider.notifier);

    // Show one-shot messages as snackbars, then clear them.
    ref.listen<String?>(
      videosViewModelProvider.select((s) => s.result),
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
