import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:petit/features/home/presentation/state/home_viewmodel_web.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel_web.dart';
import 'package:petit/features/videos/presentation/pages/videos_page_web.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../common/data/shared_media_details.dart';
import '../../../../core/constants/consts.dart';
import '../../../../service_locator.dart';
import '../../../images/presentation/pages/images_page_web.dart';
import '../../../images/presentation/widget/intro_carousel_dialog.dart';

class HomeScreenWeb extends StatefulWidget {
  const HomeScreenWeb({super.key, this.sharedMedia});

  final SharedMediaDetails? sharedMedia;

  @override
  State<HomeScreenWeb> createState() => _HomeScreenWebState();
}

class _HomeScreenWebState extends State<HomeScreenWeb> {
  @override
  void initState() {
    super.initState();

    _checkFirstLaunch();
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

  @override
  Widget build(BuildContext context) {
    return SuperBuilder(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              "Petit Web - ${getHomeViewModelWeb.currentTabIndex.state == 0 ? "Image" : "Video"} Compressor",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            elevation: 8,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          ),
          body: IndexedStack(
            index: getHomeViewModelWeb.currentTabIndex.state,
            children: const [
              ImagesPageWeb(),
              VideosPageWeb(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: getHomeViewModelWeb.currentTabIndex.state,
            onDestinationSelected: getHomeViewModelWeb.updateCurrentTabIndex,
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
    );
  }
}
