import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/core/di/providers.dart';

final outputFolderViewModelProvider =
    AsyncNotifierProvider<OutputFolderViewModel, String?>(
        OutputFolderViewModel.new);

/// The "Save to" setting. Its state is the remembered folder, or null when
/// the user wants to be asked at the start of every job.
class OutputFolderViewModel extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.read(outputFolderPreferenceProvider).read();

  /// Opens the folder dialog and remembers the choice. Cancelling changes nothing.
  Future<void> choose() async {
    final chosen = await ref
        .read(folderPickerProvider)
        .pickFolder(initialDirectory: state.value);
    if (chosen == null) return;

    await ref.read(outputFolderPreferenceProvider).write(chosen);
    state = AsyncData(chosen);
  }

  /// Forgets the folder: the app asks at the start of every job again.
  Future<void> askEachTime() async {
    await ref.read(outputFolderPreferenceProvider).write(null);
    state = const AsyncData(null);
  }
}
