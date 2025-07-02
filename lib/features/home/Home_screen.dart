import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:petit/features/home/presentation/state/home_viewmodel.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:petit/features/videos/presentation/pages/Videos_page.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/data/shared_media_details.dart';
import '../../core/constants/consts.dart';
import '../../service_locator.dart';
import '../images/presentation/pages/images_page.dart';
import '../images/presentation/widget/IntroCarouselDialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.sharedMedia});

  final SharedMediaDetails? sharedMedia;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    _checkFirstLaunch();
    if (Platform.isAndroid) {
      if (!kDebugMode) {
        _checkAndroidFlexibleUpdate();
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
        getImagesViewModel.addSharedImages(widget.sharedMedia?.sharedAttachment);
        getHomeViewModel.updateCurrentTabIndex(0);
      }

      if (widget.sharedMedia?.type == SharedMediaType.video) {
        getVideosViewModel.addSharedVideo(widget.sharedMedia?.sharedAttachment);
        getHomeViewModel.updateCurrentTabIndex(1);
      }

    });
  }

  @override
  Widget build(BuildContext context) {
    return SuperBuilder(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              "Petit - ${getHomeViewModel.currentTabIndex.state == 0 ? "Image" : "Video"} Compressor",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            elevation: 8,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          ),
          body: IndexedStack(
            index: getHomeViewModel.currentTabIndex.state,
            children: const [
              ImagesPage(),
              VideosPage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: getHomeViewModel.currentTabIndex.state,
            onDestinationSelected: getHomeViewModel.updateCurrentTabIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.image_outlined),
                selectedIcon: Icon(Icons.image),
                label: 'Images',
              ),
              NavigationDestination(
                icon: Icon(Icons.videocam_outlined),
                selectedIcon: Icon(Icons.videocam),
                label: 'Videos (Beta)',
              ),
            ],
          ),
        );
      },
    );
  }
}
