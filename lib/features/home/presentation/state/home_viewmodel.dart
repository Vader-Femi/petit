import 'package:flutter_super/flutter_super.dart';

HomeViewModel get getHomeViewModel => Super.init(HomeViewModel());

class HomeViewModel {
  final result = RxT<String?>(null);
  final isLoading = RxBool(false);
  final currentTabIndex = RxInt(0);


  void setIsLoading(bool isLoading) {
    this.isLoading.state = isLoading;
  }

  Future<void> showResult(String? result) async {
    this.result.state = result;
  }

  Future<void> updateCurrentTabIndex(int index) async {
    currentTabIndex.state = index;
  }

}
