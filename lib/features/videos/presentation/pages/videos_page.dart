import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/core/utils/adaptive.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/core/utils/shortcut_labels.dart';
import 'package:petit/features/videos/presentation/state/video_presets.dart';
import 'package:petit/features/videos/presentation/state/videos_state.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import '../../../../common/widgets/compression_summary_dialog.dart';
import '../../../../common/widgets/slider_box.dart';

class VideosPage extends ConsumerStatefulWidget {
  const VideosPage({super.key});

  @override
  ConsumerState<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends ConsumerState<VideosPage> {
  // Adjust to actual height of your FAB + margin
  static const fabHeight = 72.0;

  /// The two quality sliders.
  Widget _buildSliders(
    BuildContext context,
    VideosState state,
    VideosViewModel viewModel,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildSliderBox(
          context: context,
          label: "Compression Level",
          minValue: labelForCrfSlider(0),
          maxValue: labelForCrfSlider(100),
          tootTipMessage: "Adjusts the compression level.\n"
              "•${labelForCrfSlider(100)} = smallest size, less clarity\n"
              "•${labelForCrfSlider(0)} = smaller size, more clarity\n"
              "•Recommended = ${labelForCrfSlider(80)}",
          slider: Slider(
            value: state.crfQuality / 100,
            min: 0,
            max: 1,
            divisions: 4,
            label: "${labelForCrfSlider(state.crfQuality)} Compression",
            onChanged: viewModel.updateCfrQualitySlider,
          ),
        ),
        const SizedBox(height: 12),
        buildSliderBox(
          context: context,
          label: "Desired File Size",
          minValue: kFfmpegPresets.first.desc,
          maxValue: kFfmpegPresets.last.desc,
          tootTipMessage: //"Choose a desired file size.\n"
              "•${kFfmpegPresets.first.desc} = For archival\n"
              "•${kFfmpegPresets[1].desc} = For social media\n"
              "•${kFfmpegPresets.last.desc} = For quick sharing",
          slider: Slider(
            value: state.presetIndex.toDouble(),
            min: 0,
            max: (kFfmpegPresets.length - 1).toDouble(),
            divisions: kFfmpegPresets.length - 1,
            label: kFfmpegPresets[state.presetIndex].desc,
            onChanged: (value) => viewModel.setPresetIndex(value.toInt()),
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

    return Stack(
      alignment: Alignment.center,
      children: [
        if (preview != null && preview.isInitialized)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 15),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final previewBox = ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: preview.aspectRatio,
                    child: preview.build(context),
                  ),
                );

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
                                _buildSliders(context, state, viewModel),
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

                // Narrow: stacked, as on a phone.
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: previewBox),

                    const SizedBox(height: 12),

                    _buildSliders(context, state, viewModel),

                    // Space for FABs
                    const SizedBox(height: fabHeight),
                  ],
                );
              },
            ),
          )
        else
          Text(
            PlatformInfo.isDesktop
                ? "Add a video and start compressing\nor drop it anywhere in this window"
                : "Add a video and start compressing",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
            ),
          ),
        (state.isLoading || state.isCompressing)
            ? Container(
                color: Colors.black.withValues(alpha: 0.85),
              )
            : Container(),
        (state.isLoading) ? const CircularProgressIndicator() : Container(),
        (state.isCompressing)
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 40,
                  ),
                  CircularStepProgressIndicator(
                    totalSteps: 100,
                    currentStep: state.percentComplete,
                    stepSize: 10,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    unselectedColor:
                        Theme.of(context).colorScheme.surfaceContainer,
                    padding: 0,
                    width: 200,
                    height: 200,
                    selectedStepSize: 30,
                    roundedCap: (_, __) => true,
                  ),
                  Text(
                    "Please keep app open\nwhile compressing",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              )
            : Container(),
        (state.isCompressing)
            ? Text(
                "${state.percentComplete}%",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary),
              )
            : Container(),
      ],
    );
  }

  Widget _buildFab(
    BuildContext context,
    VideosState state,
    VideosViewModel viewModel,
  ) {
    if (state.videoFile == null) {
      return FloatingActionButton(
        onPressed: () async {
          await viewModel.pickVideo();
        },
        tooltip: withShortcut("Pick video", "O"),
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
              SizedBox(width: 30),
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
              SizedBox(width: 10),
              FloatingActionButton.extended(
                icon: const Icon(Icons.delete_outline),
                tooltip:
                    withShortcut("Remove video", "Del", withModifier: false),
                onPressed: () async {
                  viewModel.removeVideo();
                },
                label: const Text('Remove video'),
              ),
              SizedBox(width: 10),
              FloatingActionButton.extended(
                icon: const Icon(Icons.compress_outlined),
                tooltip: withShortcut("Compress Video", "Enter"),
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
