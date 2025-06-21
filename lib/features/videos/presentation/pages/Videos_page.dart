import 'package:flutter/material.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import 'package:video_player/video_player.dart';

import '../../../../common/data/Summary_report.dart';
import '../../../../common/widgets/CompressionSummaryDialog.dart';

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
    final videoPlayerHeight = MediaQuery.sizeOf(context).height / 2;

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
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: videoPlayerHeight,
                      child: AspectRatio(
                        aspectRatio: getVideosViewModel
                            .videoController.state!.value.aspectRatio,
                        child: VideoPlayer(
                            getVideosViewModel.videoController.state!),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                            "Quality: ${getVideosViewModel.globalQualitySlider.state}%"),
                        Expanded(
                            child: Slider(
                                value: ((getVideosViewModel
                                        .globalQualitySlider.state
                                        .toDouble()) /
                                    100),
                                onChanged: (value) => getVideosViewModel
                                    .updateGlobalQualitySlider(value)))
                      ],
                    ),

                    Row(
                      children: [
                        Tooltip(
                          message: "Choose a compression preset.\n"
                              "• ultrafast = fastest, biggest file\n"
                              "• slower = slower, smaller file\n"
                              "Higher compression = smaller size but slower.",
                          waitDuration: Duration(milliseconds: 300),
                          showDuration: Duration(seconds: 5),
                          child: Icon(Icons.info_outline, size: 18),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          hint: const Text("Preset"),
                          value: getVideosViewModel.selectedPreset.state,
                          items: getVideosViewModel.ffmpegPresets.map((preset) {
                            return DropdownMenuItem(
                              value: preset,
                              child: Text(preset),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              getVideosViewModel.setPreset(value);
                            }
                          },
                        ),
                      ],
                    )

                    // Column(
                    //   crossAxisAlignment: CrossAxisAlignment.start,
                    //   children: [
                    //     const Text(
                    //       "Compression Speed vs Quality",
                    //       style: TextStyle(fontWeight: FontWeight.bold),
                    //     ),
                    //     const SizedBox(height: 4),
                    //     const Text(
                    //       "Choose a preset: faster = bigger file, slower = smaller file.",
                    //       style: TextStyle(fontSize: 12, color: Colors.grey),
                    //     ),
                    //     const SizedBox(height: 8),
                    //     Align(
                    //       alignment: Alignment.centerLeft,
                    //       child: Tooltip(
                    //         message:
                    //         "Faster presets are quicker but result in larger files.\nSlower presets take more time but reduce file size.",
                    //         child: DropdownButton<String>(
                    //           hint: const Text("Preset"),
                    //           value: getVideosViewModel.selectedPreset.state,
                    //           items: getVideosViewModel.ffmpegPresets.map((preset) {
                    //             return DropdownMenuItem<String>(
                    //               value: preset,
                    //               child: Text(preset),
                    //             );
                    //           }).toList(),
                    //           onChanged: (value) {
                    //             if (value != null) {
                    //               getVideosViewModel.setPreset(value);
                    //             }
                    //           },
                    //         ),
                    //       ),
                    //     ),
                    //   ],
                    // )

                    // Align(
                    //   alignment: Alignment.centerLeft,
                    //   child: DropdownButton(
                    //     hint: Text("Preset"),
                    //     value: getVideosViewModel.selectedPreset.state,
                    //     items: getVideosViewModel.ffmpegPresets.map((preset) {
                    //       return DropdownMenuItem(
                    //         value: preset,
                    //         child: Text(preset),
                    //       );
                    //     }).toList(),
                    //     onChanged: (value) {
                    //       if (value != null) {
                    //         getVideosViewModel.setPreset(value);
                    //       }
                    //     },
                    //   ),
                    // ),
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
                    color: Colors.black.withValues(alpha: 0.75),
                  )
                : Container(),
            (getVideosViewModel.isLoading.state)
                ? const CircularProgressIndicator()
                : Container(),
            (getVideosViewModel.isCompressing.state)
                ? CircularStepProgressIndicator(
                    totalSteps: 100,
                    currentStep: getVideosViewModel.percentageComplete.state,
                    stepSize: 10,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    unselectedColor:
                        Theme.of(context).colorScheme.surfaceContainer,
                    padding: 0,
                    width: 200,
                    height: 200,
                    selectedStepSize: 30,
                    roundedCap: (_, __) => true,
                  )
                : Container(),
            (getVideosViewModel.isCompressing.state)
                ? Text(
                    "${getVideosViewModel.percentageComplete.state}%",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Container(),
            // else ...[
            //   ElevatedButton.icon(
            //     onPressed: () async {
            //       await getVideosViewModel.pickVideo();
            //     },
            //     icon: const Icon(Icons.video_library),
            //     label: const Text('Pick Video'),
            //   ),
            //   const SizedBox(height: 10),
            //   ElevatedButton.icon(
            //     onPressed: () async {
            //       final summaryReport =
            //           await getVideosViewModel.compressVideo();
            //       if (summaryReport != null) {
            //         if (mounted) {
            //           _showCompressionSummaryDialog(
            //               context: context, summaryReport: summaryReport);
            //         }
            //       }
            //     },
            //     icon: const Icon(Icons.compress),
            //     label: const Text('Compress Video'),
            //   ),
            // ],
            // const SizedBox(height: 20),
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
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (getVideosViewModel.isFabOpen.state) ...[
                    getVideosViewModel.videoController.state != null &&
                            getVideosViewModel
                                .videoController.state!.value.isInitialized
                        ? FloatingActionButton(
                            onPressed: () {
                              setState(() {
                                getVideosViewModel
                                        .videoController.state!.value.isPlaying
                                    ? getVideosViewModel.videoController.state!
                                        .pause()
                                    : getVideosViewModel.videoController.state!
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
            );
          }
        }
      }),
    );
  }
}
