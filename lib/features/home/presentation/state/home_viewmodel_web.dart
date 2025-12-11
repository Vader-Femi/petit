import 'package:flutter_super/flutter_super.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel_web.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel_web.dart';

HomeViewModelWeb get getHomeViewModelWeb => Super.init(HomeViewModelWeb());

class HomeViewModelWeb {
  final result = RxT<String?>(null);
  final isLoading = RxBool(false);
  final currentTabIndex = RxInt(0);


  void setIsLoading(bool isLoading) {
    this.isLoading.state = isLoading;
  }

  void changeTab(int newTab) {
    currentTabIndex.state = newTab;
  }

  Future<void> showResult(String? result) async {
    this.result.state = result;
  }

  Future<void> updateCurrentTabIndex(int index) async {
    if (index == 0) {
      getVideosViewModelWeb.removeVideo();
    }
    if (index == 1) {
      getImagesViewModelWeb.pickedImages.state = [];
    }
    currentTabIndex.state = index;
  }

}
