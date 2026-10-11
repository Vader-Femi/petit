import 'package:flutter_super/flutter_super.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';

import '../../../videos/presentation/state/videos_viewmodel.dart';

HomeViewModel get getHomeViewModel => Super.init(HomeViewModel());

class HomeViewModel {
  final result = RxT<String?>(null);
  final isLoading = RxBool(false);
  final currentTabIndex = RxInt(0);


  /// True while either tab is loading or compressing. Switching tabs or adding
  /// files then would clear the other tab's work, so callers must not.
  bool get isBusy => getImagesViewModel.isBusy || getVideosViewModel.isBusy;

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
      getVideosViewModel.removeVideo();
    }
    if (index == 1) {
      getImagesViewModel.pickedImages.state = [];
    }
    currentTabIndex.state = index;
  }

}
