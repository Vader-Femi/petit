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

  /// True while either tab is loading or compressing. Adding files then would
  /// replace work in progress, and two jobs must not run at once (they share
  /// one work folder), so callers must not start one.
  bool get isBusy =>
      ref.read(imagesViewModelProvider).isBusy ||
      ref.read(videosViewModelProvider).isBusy;

  /// Selects a tab. Each tab keeps what was picked and its settings, so the
  /// user can look at the other tab and come back.
  Future<void> updateCurrentTabIndex(int index) async {
    if (index != 1) {
      // The Videos page stays alive under the Images tab; stop its playback.
      ref.read(videosViewModelProvider.notifier).pausePlayback();
    }
    state = index;
  }
}
