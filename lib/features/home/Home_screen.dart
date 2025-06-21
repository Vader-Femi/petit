import 'package:flutter/material.dart';
import 'package:flutter_super/flutter_super.dart';
import 'package:petit/features/home/presentation/state/home_viewmodel.dart';
import 'package:petit/features/videos/presentation/pages/Videos_page.dart';
import '../images/presentation/pages/images_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
