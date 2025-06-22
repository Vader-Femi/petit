import 'package:async/async.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import '../../../../common/data/Summary_report.dart';
import '../../../../common/widgets/CompressionSummaryDialog.dart';
import '../widget/image_quality_slider_box.dart';

class ImagesPage extends StatefulWidget {
  const ImagesPage({
    super.key,
    // this.sharedFiles
  });

  // final List<SharedMediaFile>? sharedFiles;


  @override
  State<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends State<ImagesPage> {

  @override
  void initState() {
    super.initState();
    getImagesViewModel.addSharedImages(
        // widget.sharedFiles
        );
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
    final carouselHeight = MediaQuery.sizeOf(context).height / 2.3;

    final carouselSliderController = CarouselSliderController();

    const fabHeight = 72.0; // Adjust to actual height of your FAB + margin

    return Scaffold(
      body: SuperBuilder(builder: (context) {
        if (getImagesViewModel.result.state != null) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("${getImagesViewModel.result.state}"),
            ));
            getImagesViewModel.showResult(null);
          });
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            getImagesViewModel.pickedImages.isEmpty
                ? const Text(
                    "Add images and start compressing",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.fromLTRB(10, 10, 10, 15),
                    child: Column(
                      children: [
                        Expanded(
                          child: CarouselSlider(
                            items: getImagesViewModel.pickedImages.state
                                .map((imageData) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  imageData.imageFile,
                                  frameBuilder: (BuildContext context,
                                      Widget child,
                                      int? frame,
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
                                ),
                              );
                            }).toList(),
                            carouselController: carouselSliderController,
                            options: CarouselOptions(
                                autoPlay: true,
                                enlargeStrategy:
                                    CenterPageEnlargeStrategy.zoom,
                                enlargeCenterPage: true,
                                pageSnapping: true,
                                scrollDirection: Axis.horizontal,
                                pauseAutoPlayOnTouch: true,
                                enableInfiniteScroll: false,
                                onPageChanged: (index, _) => getImagesViewModel
                                    .updateCurrentImageAndIndex(index),
                                reverse: false),
                          ),
                        ),
                        SizedBox(height: 10),
                        // Current image index
                        if (getImagesViewModel.pickedImages.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              "${(getImagesViewModel.currentImageIndex.state ?? -1) + 1} of ${getImagesViewModel.pickedImages.state.length}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),

                        SizedBox(height: 10),

                        if (getImagesViewModel.currentImage.state != null)
                          ImageQualitySliderBox(
                            sliderValue: (getImagesViewModel.globalQualitySlider.state ??
                                getImagesViewModel.currentImage.state!.quality) /
                                100,
                            isGlobal: getImagesViewModel.globalQualitySlider.state != null,
                            showGlobalSwitch: getImagesViewModel.pickedImages.length > 1,
                            onSliderChanged: (value) {
                              if (getImagesViewModel.globalQualitySlider.state != null) {
                                getImagesViewModel.updateGlobalQualitySlider(value);
                              } else {
                                getImagesViewModel.updateCurrentImageQuality(value);
                              }
                            },
                            onGlobalToggle: (value) {
                              getImagesViewModel.globalQualitySlider.state = value ? 90 : null;
                            },
                          ),

                        // Reserve space for FABs
                        const SizedBox(height: 72.0),
                      ],
                    ),
                  ),
            getImagesViewModel.isLoading.state.isLoading
                ? Container(
                    color: Colors.black.withValues(alpha: 0.75),
                  )
                : Container(),
            getImagesViewModel.isLoading.state.isLoading
                ? getImagesViewModel.isLoading.state.totalSteps == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text("Loading Please Wait"),
                          SizedBox(height: 5),
                          CircularProgressIndicator()
                        ],
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(50)),
                        child: Text(
                          '${getImagesViewModel.isLoading.state.progressCounter}%',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer),
                        ),
                      )
                : Container(),
            (getImagesViewModel.isLoading.state.isLoading &&
                    getImagesViewModel.isLoading.state.totalSteps != null)
                ? CircularStepProgressIndicator(
                    totalSteps:
                        getImagesViewModel.isLoading.state.totalSteps ?? 1,
                    stepSize: 20,
                    selectedStepSize: 30,
                    currentStep:
                        getImagesViewModel.isLoading.state.completedSteps ?? 1,
                    width: 180,
                    height: 180,
                    padding: 0.02,
                    selectedColor: Colors.green,
                    unselectedColor: Colors.red,
                  )
                : Container(),
          ],
        );
      }),

      floatingActionButton: SuperBuilder(
        builder: (context) {
          if (getImagesViewModel.pickedImages.isEmpty) {
            return FloatingActionButton(
              onPressed: () async =>
                  getImagesViewModel.selectImageButtonUseCase(),
              tooltip: "Add Images",
              child: const Icon(Icons.add_photo_alternate_outlined),
            );
          } else {
            if (getImagesViewModel.isLoading.state.isLoading) {
              return FloatingActionButton.extended(
                icon: const Icon(Icons.clear),
                tooltip: "Cancel compression ",
                onPressed: () async {
                  try {
                    if (!getImagesViewModel.completer.isCanceled ||
                        !getImagesViewModel.completer.isCompleted) {
                      getImagesViewModel.completer.operation.cancel();
                    }
                    getImagesViewModel.showResult("Cancelling");
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
                    if (getImagesViewModel.isFabOpen.state) ...[
                      FloatingActionButton.extended(
                        icon: const Icon(Icons.compress_outlined),
                        tooltip: "Compress Images",
                        onPressed: () async {
                          getImagesViewModel.completer = CancelableCompleter(
                            onCancel: getImagesViewModel.cancelCompressingAllImages,
                          );

                          getImagesViewModel.completer.complete(getImagesViewModel
                              .compressAllSelectedImages()
                              .then((summaryReport) {
                            if (summaryReport != null) {
                              if (mounted) {
                                _showCompressionSummaryDialog(
                                    context: context,
                                    summaryReport: summaryReport);
                              }
                            }
                          }));
                        },
                        label: const Text('Compress'),
                      ),
                      SizedBox(width: 10),
                      FloatingActionButton.extended(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: "Remove images",
                        onPressed: () async {
                          getImagesViewModel.cancelCompressingAllImages();
                        },
                        label: const Text('Clear'),
                      ),
                    ],
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      heroTag: "toggle_fab",
                      onPressed: () {
                        setState(() {
                          getImagesViewModel.isFabOpen.state =
                              !getImagesViewModel.isFabOpen.state;
                        });
                      },
                      tooltip: getImagesViewModel.isFabOpen.state
                          ? "Close Actions"
                          : "Show Actions",
                      child: Icon(getImagesViewModel.isFabOpen.state
                          ? Icons.close
                          : Icons.compress_outlined),
                    ),
                  ],
                ),
              );
            }
          }
        },
      ),
    );
  }
}
