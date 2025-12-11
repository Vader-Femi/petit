import 'package:flutter/material.dart';
import 'package:flutter_super/flutter_super.dart';
// Conditional import for VideosViewModel
import 'package:petit/features/videos/presentation/state/videos_viewmodel_web.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import 'package:video_player/video_player.dart';
import '../../../../common/data/summary_report.dart';
import '../../../../common/widgets/compression_summary_dialog.dart';
import '../../../../common/widgets/slider_box.dart';

class VideosPageWeb extends StatefulWidget {
  const VideosPageWeb({super.key});

  @override
  State<VideosPageWeb> createState() => _VideosPageWebState();
}

class _VideosPageWebState extends State<VideosPageWeb> {
  @override
  void dispose() {
    // getVideosViewModelWeb.videoController.state?.dispose();
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
        if (getVideosViewModelWeb.result.state != null) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("${getVideosViewModelWeb.result.state}"),
            ));
            getVideosViewModelWeb.showResult(null);
          });
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            if (getVideosViewModelWeb.videoController.state != null &&
                getVideosViewModelWeb.videoController.state!.value.isInitialized)
              Padding(
                padding: EdgeInsets.fromLTRB(10, 10, 10, 15),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: getVideosViewModelWeb
                              .videoController.state!.value.aspectRatio,
                          child: VideoPlayer(
                              getVideosViewModelWeb.videoController.state!),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Column(
                      children: [
                        buildSliderBox(
                          context: context,
                          label: "Compression Level",
                          minValue: getVideosViewModelWeb.getLabelForCRFSlider(0),
                          maxValue: getVideosViewModelWeb.getLabelForCRFSlider(100),
                          tootTipMessage: "Adjusts the compression level.\n"
                              "•${getVideosViewModelWeb.getLabelForCRFSlider(100)} = smallest size, less clarity\n"
                              "•${getVideosViewModelWeb.getLabelForCRFSlider(0)} = smaller size, more clarity\n"
                              "•Recommended = ${getVideosViewModelWeb.getLabelForCRFSlider(80)}",
                          slider: Slider(
                            value:
                            getVideosViewModelWeb.cfrQualitySlider.state / 100,
                            min: 0,
                            max: 1,
                            divisions: 4,
                            label: "${getVideosViewModelWeb.getLabelForCRFSlider(
                                getVideosViewModelWeb.cfrQualitySlider.state)} Compression",
                            onChanged: (value) {
                              getVideosViewModelWeb
                                  .updateCfrQualitySlider(value);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        buildSliderBox(
                          context: context,
                          label: "Desired File Size",
                          minValue: getVideosViewModelWeb.ffmpegPresets.first.desc,
                          maxValue: getVideosViewModelWeb.ffmpegPresets.last.desc,
                          tootTipMessage: //"Choose a desired file size.\n"
                          "•${getVideosViewModelWeb.ffmpegPresets.first.desc} = For archival\n"
                              "•${getVideosViewModelWeb.ffmpegPresets[1].desc} = For social media\n"
                              "•${getVideosViewModelWeb.ffmpegPresets.last.desc} = For quick sharing",
                          slider: Slider(
                            value: getVideosViewModelWeb.selectedPresetIndex.state
                                .toDouble(),
                            min: 0,
                            max: (getVideosViewModelWeb.ffmpegPresets.length - 1)
                                .toDouble(),
                            divisions:
                            getVideosViewModelWeb.ffmpegPresets.length - 1,
                            label: getVideosViewModelWeb.ffmpegPresets[
                            getVideosViewModelWeb.selectedPresetIndex.state].desc,
                            onChanged: (value) {
                              getVideosViewModelWeb.setPresetIndex(value.toInt());
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
            (getVideosViewModelWeb.isLoading.state ||
                getVideosViewModelWeb.isCompressing.state)
                ? Container(
              color: Colors.black.withValues(alpha: 0.85),
            )
                : Container(),
            (getVideosViewModelWeb.isLoading.state)
                ? const CircularProgressIndicator()
                : Container(),
            (getVideosViewModelWeb.isCompressing.state)
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 40,
                ),
                CircularStepProgressIndicator(
                  totalSteps: 100,
                  currentStep:
                  getVideosViewModelWeb.percentageComplete.state,
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
            (getVideosViewModelWeb.isCompressing.state)
                ? Text(
              "${getVideosViewModelWeb.percentageComplete.state}%",
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
        if (getVideosViewModelWeb.videoFile.state == null) {
          return FloatingActionButton(
            onPressed: () async {
              await getVideosViewModelWeb.pickVideo();
            },
            tooltip: "Pick video",
            child: const Icon(Icons.video_library),
          );
        } else {
          if (getVideosViewModelWeb.isCompressing.state) {
            if (getVideosViewModelWeb.currentSession.state != null ) {
              return FloatingActionButton.extended(
                icon: const Icon(Icons.clear),
                tooltip: "Cancel compression ",
                onPressed: () async {
                  try {
                    getVideosViewModelWeb.cancelCompressingVideo();
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
                    if (getVideosViewModelWeb.isFabOpen.state) ...[
                      SizedBox(width: 30),
                      getVideosViewModelWeb.videoController.state != null &&
                          getVideosViewModelWeb
                              .videoController.state!.value.isInitialized
                          ? FloatingActionButton(
                        onPressed: () {
                          setState(() {
                            getVideosViewModelWeb.videoController.state!
                                .value.isPlaying
                                ? getVideosViewModelWeb
                                .videoController.state!
                                .pause()
                                : getVideosViewModelWeb
                                .videoController.state!
                                .play();
                          });
                        },
                        child: Icon(
                          getVideosViewModelWeb
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
                          getVideosViewModelWeb.removeVideo();
                        },
                        label: const Text('Remove video'),
                      ),
                      SizedBox(width: 10),
                      FloatingActionButton.extended(
                        icon: const Icon(Icons.compress_outlined),
                        tooltip: "Compress Video",
                        onPressed: () async {
                          await getVideosViewModelWeb.compressVideo(
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
                          getVideosViewModelWeb.isFabOpen.state =
                          !getVideosViewModelWeb.isFabOpen.state;
                        });
                      },
                      tooltip: getVideosViewModelWeb.isFabOpen.state
                          ? "Close Actions"
                          : "Show Actions",
                      child: Icon(getVideosViewModelWeb.isFabOpen.state
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
