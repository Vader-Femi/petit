import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/common/widgets/compression_summary_dialog.dart';
import 'package:petit/common/widgets/drop_zone.dart';
import 'package:petit/core/utils/adaptive.dart';
import 'package:petit/core/utils/dropped_files.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/features/home/presentation/state/home_viewmodel.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:petit/features/videos/presentation/pages/videos_page.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../common/data/shared_media_details.dart';
import '../../../../core/constants/consts.dart';
import '../../../../service_locator.dart';
import '../../../images/presentation/pages/images_page.dart';
import '../../../images/presentation/widget/intro_carousel_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.sharedMedia});

  final SharedMediaDetails? sharedMedia;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeViewModel get _home => ref.read(homeViewModelProvider.notifier);
  ImagesViewModel get _images => ref.read(imagesViewModelProvider.notifier);
  VideosViewModel get _videos => ref.read(videosViewModelProvider.notifier);

  @override
  void initState() {
    super.initState();

    _checkFirstLaunch();
    if (!kIsWeb) {
    if (Platform.isAndroid) {
      if (!kDebugMode) {
        _checkAndroidFlexibleUpdate();
      }
    }
    }

    _handleSharedAttachment();
  }

  Future<void> _checkFirstLaunch() async {
    var prefs = sl.call<SharedPreferencesAsync>();
    final hasSeenDialog =
        await prefs.getBool(Consts.hasSeenIntroDialog) ?? false;

    if (!hasSeenDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIntroDialogCarousel();
      });
      await prefs.setBool(Consts.hasSeenIntroDialog, true);
    }
  }

  void _showIntroDialogCarousel() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const IntroCarouselDialog(),
    );
  }

  Future<void> _checkAndroidFlexibleUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable &&
          updateInfo.flexibleUpdateAllowed == true) {
        try {
          await InAppUpdate.startFlexibleUpdate();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Update ready to install'),
                action: SnackBarAction(
                  label: 'Restart now',
                  onPressed: () async {
                    try {
                      await InAppUpdate.completeFlexibleUpdate();
                    } catch (e) {
                      debugPrint("Error completing update: $e");
                    }
                  },
                ),
                duration: const Duration(hours: 1), // effectively permanent
              ),
            );
          }
        } on PlatformException catch (e) {
          debugPrint("In-app update error: ${e.message}");
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
    }
  }

  Future<void> _handleSharedAttachment() async {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {

      if (widget.sharedMedia?.type == SharedMediaType.image) {
        _images.addSharedImages(widget.sharedMedia?.sharedAttachment);
        _home.updateCurrentTabIndex(0);
      }

      if (widget.sharedMedia?.type == SharedMediaType.video) {
        _videos.addSharedVideo(widget.sharedMedia?.sharedAttachment);
        _home.updateCurrentTabIndex(1);
      }

    });
  }

  // ---- keyboard shortcuts -------------------------------------------------

  bool get _isApple => PlatformInfo.isMacOS || PlatformInfo.isIOS;

  /// Ctrl on Windows/Linux, Cmd on Apple platforms.
  SingleActivator _withModifier(LogicalKeyboardKey key) =>
      SingleActivator(key, control: !_isApple, meta: _isApple);

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
        _withModifier(LogicalKeyboardKey.keyO): _openFiles,
        _withModifier(LogicalKeyboardKey.enter): _compress,
        _withModifier(LogicalKeyboardKey.numpadEnter): _compress,
        const SingleActivator(LogicalKeyboardKey.delete): _clear,
        _withModifier(LogicalKeyboardKey.backspace): _clear,
        const SingleActivator(LogicalKeyboardKey.escape): _cancelRunning,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _previousImage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _nextImage,
        _withModifier(LogicalKeyboardKey.digit1): () => _selectTab(0),
        _withModifier(LogicalKeyboardKey.digit2): () => _selectTab(1),
      };

  int get _tab => ref.read(homeViewModelProvider);

  void _openFiles() {
    if (_home.isBusy) return;
    if (_tab == 0) {
      _images.pickImages();
    } else {
      _videos.pickVideo();
    }
  }

  void _compress() {
    if (_home.isBusy) return;
    if (_tab == 0) {
      if (ref.read(imagesViewModelProvider).pickedImages.isEmpty) return;
      _images.startCompression(onComplete: _showSummary);
    } else {
      if (ref.read(videosViewModelProvider).videoFile == null) return;
      _videos.compressVideo(onComplete: _showSummary);
    }
  }

  void _clear() {
    if (_home.isBusy) return;
    if (_tab == 0) {
      _images.clearPickedImages();
    } else {
      _videos.removeVideo();
    }
  }

  void _cancelRunning() {
    if (_images.isBusy &&
        ref.read(imagesViewModelProvider).pickedImages.isNotEmpty) {
      _images.requestCancel();
    } else if (ref.read(videosViewModelProvider).currentJob != null) {
      _videos.cancelCompressingVideo();
    }
  }

  void _previousImage() {
    if (_tab == 0 && !_images.isBusy) {
      _images.previousImage();
    }
  }

  void _nextImage() {
    if (_tab == 0 && !_images.isBusy) {
      _images.nextImage();
    }
  }

  void _selectTab(int index) {
    if (_home.isBusy || _tab == index) return;
    _home.updateCurrentTabIndex(index);
  }

  void _showSummary(SummaryReport summaryReport) {
    if (!mounted) return;
    showCompressionSummaryDialog(context: context, summaryReport: summaryReport);
  }

  // ---- drag and drop ------------------------------------------------------

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleDroppedFiles(List<String> droppedPaths) async {
    // Switching tabs clears the other tab's work, so never do it mid-job.
    if (_home.isBusy) {
      _snack('Wait for the current job to finish.');
      return;
    }

    final media = classifyDroppedFiles(expandDroppedFolders(droppedPaths));

    if (media.isEmpty) {
      _snack('Drop images (JPG, PNG, WebP, HEIC) or a video file.');
      return;
    }

    if (media.images.isNotEmpty) {
      await _home.updateCurrentTabIndex(0);
      await _images.addImagePaths(media.images);
      if (media.videos.isNotEmpty) {
        _snack('Added the images. Drop videos separately.');
      }
    } else {
      await _home.updateCurrentTabIndex(1);
      await _videos.addVideoPath(media.videos.first);
      if (media.videos.length > 1) {
        _snack('Only one video can be compressed at a time.');
      }
    }
  }

  // ---- layout -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selectedTab = ref.watch(homeViewModelProvider);

    return CallbackShortcuts(
      bindings: _shortcuts,
      child: Focus(
        autofocus: true,
        child: DropZone(
          onFilesDropped: _handleDroppedFiles,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Wide windows get a side rail; narrow ones the bottom bar.
              final useRail = constraints.maxWidth >= kRailMinWidth;

              final pages = IndexedStack(
                index: selectedTab,
                children: const [
                  ImagesPage(),
                  VideosPage(),
                ],
              );

              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    "Petit - ${selectedTab == 0 ? "Image" : "Video"} Compressor",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  elevation: 8,
                  backgroundColor:
                      Theme.of(context).appBarTheme.backgroundColor,
                ),
                body: useRail
                    ? Row(
                        children: [
                          NavigationRail(
                            selectedIndex: selectedTab,
                            onDestinationSelected:
                                _home.updateCurrentTabIndex,
                            labelType: NavigationRailLabelType.all,
                            destinations: const [
                              NavigationRailDestination(
                                icon: Icon(Icons.image_outlined),
                                selectedIcon: Icon(Icons.image),
                                label: Text('Images'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.videocam_outlined),
                                selectedIcon: Icon(Icons.videocam),
                                label: Text('Videos'),
                              ),
                            ],
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: pages),
                        ],
                      )
                    : pages,
                bottomNavigationBar: useRail
                    ? null
                    : NavigationBar(
                        selectedIndex: selectedTab,
                        onDestinationSelected:
                            _home.updateCurrentTabIndex,
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.image_outlined),
                            selectedIcon: Icon(Icons.image),
                            label: 'Images',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.videocam_outlined),
                            selectedIcon: Icon(Icons.videocam),
                            label: 'Videos',
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}
