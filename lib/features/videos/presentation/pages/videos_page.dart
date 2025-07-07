import 'package:flutter/material.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import 'package:video_player/video_player.dart';
import '../../../../common/data/summary_report.dart';
import '../../../../common/widgets/compression_summary_dialog.dart';
import '../../../../common/widgets/slider_box.dart';

class VideosPagePlaceholder extends StatelessWidget {
  const VideosPagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Coming Soon',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  @override
  void dispose() {
    // getVideosViewModel.videoController.state?.dispose();
    super.dispose();
  }

  void _showCompressionSummaryDialog({
    required BuildContext context,
    required SummaryReport summaryReport,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          CompressionSummaryDialog(summaryReport: summaryReport),
    );
  }

  @override
  Widget build(BuildContext context) {
    const fabHeight = 72.0; // Adjust to actual height of your FAB + margin

    return Scaffold(
      body: SuperBuilder(builder: (context) {
        if (getVideosViewModel.result.state != null) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("${getVideosViewModel.result.state}"),
            ));
            getVideosViewModel.showResult(null);
          });
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            if (getVideosViewModel.videoController.state != null &&
                getVideosViewModel.videoController.state!.value.isInitialized)
              Padding(
                padding: EdgeInsets.fromLTRB(10, 10, 10, 15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: getVideosViewModel
                              .videoController.state!.value.aspectRatio,
                          child: VideoPlayer(
                              getVideosViewModel.videoController.state!),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Column(
                      children: [
                        buildSliderBox(
                          context: context,
                          label: "Compression Level",
                          minValue: getVideosViewModel.getLabelForCRFSlider(0),
                          maxValue: getVideosViewModel.getLabelForCRFSlider(100),
                          tootTipMessage: "Adjusts the compression level.\n"
                              "•${getVideosViewModel.getLabelForCRFSlider(100)} = smallest size, less clarity\n"
                              "•${getVideosViewModel.getLabelForCRFSlider(0)} = smaller size, more clarity\n"
                              "•Recommended = ${getVideosViewModel.getLabelForCRFSlider(80)}",
                          slider: Slider(
                            value:
                                getVideosViewModel.cfrQualitySlider.state / 100,
                            min: 0,
                            max: 1,
                            divisions: 4,
                            label: "${getVideosViewModel.getLabelForCRFSlider(
                                getVideosViewModel.cfrQualitySlider.state)} Compression",
                            onChanged: (value) {
                              getVideosViewModel
                                  .updateCfrQualitySlider(value);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        buildSliderBox(
                          context: context,
                          label: "Desired File Size",
                          minValue: getVideosViewModel.ffmpegPresets.first.desc,
                          maxValue: getVideosViewModel.ffmpegPresets.last.desc,
                          tootTipMessage: //"Choose a desired file size.\n"
                              "•${getVideosViewModel.ffmpegPresets.first.desc} = For archival\n"
                              "•${getVideosViewModel.ffmpegPresets[1].desc} = For social media\n"
                              "•${getVideosViewModel.ffmpegPresets.last.desc} = For quick sharing",
                          slider: Slider(
                            value: getVideosViewModel.selectedPresetIndex.state
                                .toDouble(),
                            min: 0,
                            max: (getVideosViewModel.ffmpegPresets.length - 1)
                                .toDouble(),
                            divisions:
                                getVideosViewModel.ffmpegPresets.length - 1,
                            label: getVideosViewModel.ffmpegPresets[
                                getVideosViewModel.selectedPresetIndex.state].desc,
                            onChanged: (value) {
                              getVideosViewModel.setPresetIndex(value.toInt());
                            },
                          ),
                        ),
                      ],
                    ),

                    // Space for FABs
                    const SizedBox(height: fabHeight),
                  ],
                ),
              )
            else
              const Text(
                "Add a video and start compressing",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            (getVideosViewModel.isLoading.state ||
                    getVideosViewModel.isCompressing.state)
                ? Container(
                    color: Colors.black.withValues(alpha: 0.85),
                  )
                : Container(),
            (getVideosViewModel.isLoading.state)
                ? const CircularProgressIndicator()
                : Container(),
            (getVideosViewModel.isCompressing.state)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 40,
                      ),
                      CircularStepProgressIndicator(
                        totalSteps: 100,
                        currentStep:
                            getVideosViewModel.percentageComplete.state,
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
            (getVideosViewModel.isCompressing.state)
                ? Text(
                    "${getVideosViewModel.percentageComplete.state}%",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary),
                  )
                : Container(),
          ],
        );
      }),
      floatingActionButton: SuperBuilder(builder: (context) {
        if (getVideosViewModel.videoFile.state == null) {
          return FloatingActionButton(
            onPressed: () async {
              await getVideosViewModel.pickVideo();
            },
            tooltip: "Pick video",
            child: const Icon(Icons.video_library),
          );
        } else {
          if (getVideosViewModel.isCompressing.state) {
            if (getVideosViewModel.currentSession.state != null ) {
              return FloatingActionButton.extended(
                icon: const Icon(Icons.clear),
                tooltip: "Cancel compression ",
                onPressed: () async {
                  try {
                    getVideosViewModel.cancelCompressingVideo();
                  } catch (e) {
                    debugPrint('Error during cancel: $e');
                  }
                },
                label: const Text('Cancel'),
              );
            } else {
              return Container();
            }
          } else {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (getVideosViewModel.isFabOpen.state) ...[
                      SizedBox(width: 30),
                      getVideosViewModel.videoController.state != null &&
                              getVideosViewModel
                                  .videoController.state!.value.isInitialized
                          ? FloatingActionButton(
                              onPressed: () {
                                setState(() {
                                  getVideosViewModel.videoController.state!
                                          .value.isPlaying
                                      ? getVideosViewModel
                                          .videoController.state!
                                          .pause()
                                      : getVideosViewModel
                                          .videoController.state!
                                          .play();
                                });
                              },
                              child: Icon(
                                getVideosViewModel
                                        .videoController.state!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                            )
                          : Container(),
                      SizedBox(width: 10),
                      FloatingActionButton.extended(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: "Remove video",
                        onPressed: () async {
                          getVideosViewModel.removeVideo();
                        },
                        label: const Text('Remove video'),
                      ),
                      SizedBox(width: 10),
                      FloatingActionButton.extended(
                        icon: const Icon(Icons.compress_outlined),
                        tooltip: "Compress Video",
                        onPressed: () async {
                          await getVideosViewModel.compressVideo(
                              onComplete: (summaryReport) {
                            if (mounted) {
                              _showCompressionSummaryDialog(
                                  context: context,
                                  summaryReport: summaryReport);
                            }
                          });
                        },
                        label: const Text('Compress'),
                      ),
                    ],
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      heroTag: "toggle_fab",
                      onPressed: () {
                        setState(() {
                          getVideosViewModel.isFabOpen.state =
                              !getVideosViewModel.isFabOpen.state;
                        });
                      },
                      tooltip: getVideosViewModel.isFabOpen.state
                          ? "Close Actions"
                          : "Show Actions",
                      child: Icon(getVideosViewModel.isFabOpen.state
                          ? Icons.close
                          : Icons.compress_outlined),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      }),
    );
  }
}
