import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';

final homeViewModelProvider =
    NotifierProvider<HomeViewModel, int>(HomeViewModel.new);

/// ViewModel of the home screen. Its state is the selected tab (0 = images,
/// 1 = videos).
class HomeViewModel extends Notifier<int> {
  @override
  int build() => 0;

  /// True while either tab is loading or compressing. Switching tabs or adding
  /// files then would clear the other tab's work, so callers must not.
  bool get isBusy =>
      ref.read(imagesViewModelProvider).isBusy ||
      ref.read(videosViewModelProvider).isBusy;

  /// Selects a tab. Leaving a tab discards its content.
  Future<void> updateCurrentTabIndex(int index) async {
    if (index == 0) {
      ref.read(videosViewModelProvider.notifier).removeVideo();
    }
    if (index == 1) {
      ref.read(imagesViewModelProvider.notifier).clearPickedImages();
    }
    state = index;
  }
}
