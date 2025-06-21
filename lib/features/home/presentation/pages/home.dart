import 'dart:io';
import 'package:async/async.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:petit/features/home/presentation/state/home_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import '../../../../core/constants/consts.dart';
import '../data/Summary_report.dart';
import '../widget/CompressionSummaryDialog.dart';
import '../widget/IntroCarouselDialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    // this.sharedFiles
  });

  // final List<SharedMediaFile>? sharedFiles;


  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  @override
  void initState() {
    super.initState();
    getHomeViewModel.addSharedImages(
        // widget.sharedFiles
        );
    _checkFirstLaunch();
    if (Platform.isAndroid) {
      if (!kDebugMode) {
        _checkAndroidFlexibleUpdate();
      }
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenDialog = prefs.getBool(Consts.hasSeenIntroDialog) ?? false;

    if (!hasSeenDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIntroDialogCarousel();
      });
      await prefs.setBool(Consts.hasSeenIntroDialog, true);
    }
  }


  Future<void> _checkAndroidFlexibleUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable &&
          updateInfo.flexibleUpdateAllowed == true) {

        try {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        } on PlatformException catch (e) {
          debugPrint("In-app update error: ${e.message}");
          throw Exception('Error during in-app update: $e');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Update downloaded! Restart the app to apply'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("In-app update error: $e");
      throw Exception('Error during in-app update: $e');
    }
  }



  void _showIntroDialogCarousel() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const IntroCarouselDialog(),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Petit - Image Compressor",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 8,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: SuperBuilder(builder: (context) {
        if (getHomeViewModel.result.state != null) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("${getHomeViewModel.result.state}"),
            ));
            getHomeViewModel.showResult(null);
          });
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            getHomeViewModel.pickedImages.isEmpty
                ? const Text(
                    "Add images and start compressing",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.fromLTRB(10, 0, 10, 15),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CarouselSlider(
                          items: getHomeViewModel.pickedImages.state
                              .map((imageData) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                imageData.imageFile,
                                height: carouselHeight,
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
                                fit: BoxFit.fitHeight,
                                filterQuality: FilterQuality.none,
                              ),
                            );
                          }).toList(),
                          carouselController: carouselSliderController,
                          options: CarouselOptions(
                              height: carouselHeight,
                              autoPlay: true,
                              enlargeStrategy:
                                  CenterPageEnlargeStrategy.zoom,
                              enlargeCenterPage: true,
                              pageSnapping: true,
                              scrollDirection: Axis.horizontal,
                              pauseAutoPlayOnTouch: true,
                              enableInfiniteScroll: false,
                              onPageChanged: (index, _) => getHomeViewModel
                                  .updateCurrentImageAndIndex(index),
                              reverse: false),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "${(getHomeViewModel.currentImageIndex.state ?? -1) + 1} of ${getHomeViewModel.pickedImages.state.length}",
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 10),
                        getHomeViewModel.currentImage.state != null
                            ? Row(
                                children: [
                                  Text(
                                      "Quality: ${getHomeViewModel.globalQualitySlider.state ?? getHomeViewModel.currentImage.state?.quality}%"),
                                  Expanded(
                                      child: getHomeViewModel.globalQualitySlider.state != null
                                          ? Slider(
                                              value: ((getHomeViewModel
                                                          .globalQualitySlider
                                                          .state
                                                          ?.toDouble() ??
                                                      90.0) /
                                                  100),
                                              onChanged: (value) =>
                                                  getHomeViewModel
                                                      .updateGlobalQualitySlider(
                                                          value))
                                          : Slider(
                                              value: ((getHomeViewModel
                                                          .currentImage
                                                          .state
                                                          ?.quality
                                                          .toDouble() ??
                                                      90.0) /
                                                  100),
                                              onChanged: (value) =>
                                                  getHomeViewModel.updateCurrentImageQuality(value))),
                                ],
                              )
                            : Container(),
                        SizedBox(height: 10),
                        (getHomeViewModel.currentImage.state != null &&
                                getHomeViewModel.pickedImages.length > 1)
                            ? Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                      child: Text(
                                          "Use same quality for all images",
                                          softWrap: true)),
                                  SizedBox(width: 5),
                                  SizedBox(
                                    height: 40,
                                    child: FittedBox(
                                      fit: BoxFit.fill,
                                      child: Switch(
                                          value: getHomeViewModel
                                                  .globalQualitySlider
                                                  .state !=
                                              null,
                                          onChanged: (value) {
                                            if (getHomeViewModel
                                                    .globalQualitySlider
                                                    .state ==
                                                null) {
                                              getHomeViewModel
                                                  .globalQualitySlider
                                                  .state = 90;
                                            } else {
                                              getHomeViewModel
                                                  .globalQualitySlider
                                                  .state = null;
                                            }
                                          }),
                                    ),
                                  ),
                                ],
                              )
                            : Container(),
                      ],
                    ),
                  ),
            getHomeViewModel.isLoading.state.isLoading
                ? Container(
                    color: Colors.black.withValues(alpha: 0.75),
                  )
                : Container(),
            getHomeViewModel.isLoading.state.isLoading
                ? getHomeViewModel.isLoading.state.totalSteps == null
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
                          '${getHomeViewModel.isLoading.state.progressCounter}%',
                          style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer),
                        ),
                      )
                : Container(),
            (getHomeViewModel.isLoading.state.isLoading &&
                    getHomeViewModel.isLoading.state.totalSteps != null)
                ? CircularStepProgressIndicator(
                    totalSteps:
                        getHomeViewModel.isLoading.state.totalSteps ?? 1,
                    stepSize: 20,
                    selectedStepSize: 30,
                    currentStep:
                        getHomeViewModel.isLoading.state.completedSteps ?? 1,
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
          if (getHomeViewModel.pickedImages.isEmpty) {
            return FloatingActionButton(
              onPressed: () async =>
                  getHomeViewModel.selectImageButtonUseCase(),
              tooltip: "Add Images",
              child: const Icon(Icons.add_photo_alternate_outlined),
            );
          } else {
            if (getHomeViewModel.isLoading.state.isLoading) {
              return FloatingActionButton.extended(
                icon: const Icon(Icons.clear),
                tooltip: "Cancel compression ",
                onPressed: () async {
                  try {
                    if (!getHomeViewModel.completer.isCanceled ||
                        !getHomeViewModel.completer.isCompleted) {
                      getHomeViewModel.completer.operation.cancel();
                    }
                    getHomeViewModel.showResult("Cancelling");
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
                    if (getHomeViewModel.isFabOpen.state) ...[
                      FloatingActionButton.extended(
                        icon: const Icon(Icons.compress_outlined),
                        tooltip: "Compress Images",
                        onPressed: () async {
                          getHomeViewModel.completer = CancelableCompleter(
                            onCancel: getHomeViewModel.cancelCompressingAllImages,
                          );

                          getHomeViewModel.completer.complete(getHomeViewModel
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
                        tooltip: "Clear images",
                        onPressed: () async {
                          getHomeViewModel.cancelCompressingAllImages();
                        },
                        label: const Text('Clear'),
                      ),
                    ],
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      heroTag: "toggle_fab",
                      onPressed: () {
                        setState(() {
                          getHomeViewModel.isFabOpen.state =
                              !getHomeViewModel.isFabOpen.state;
                        });
                      },
                      tooltip: getHomeViewModel.isFabOpen.state
                          ? "Close Actions"
                          : "Show Actions",
                      child: Icon(getHomeViewModel.isFabOpen.state
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
