import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit/common/state/output_folder_viewmodel.dart';
import 'package:petit/core/di/providers.dart';

import 'helpers/folder_fakes.dart';

void main() {
  ProviderContainer makeContainer(FakeFolderPicker picker, FakePreference preference) {
    return ProviderContainer.test(overrides: [
      folderPickerProvider.overrideWithValue(picker),
      outputFolderPreferenceProvider.overrideWithValue(preference),
    ]);
  }

  test('starts with the remembered folder', () async {
    final c = makeContainer(FakeFolderPicker(), FakePreference('/photos/petit'));

    expect(await c.read(outputFolderViewModelProvider.future), '/photos/petit');
  });

  test('starts as "ask each time" when nothing is remembered', () async {
    final c = makeContainer(FakeFolderPicker(), FakePreference());

    expect(await c.read(outputFolderViewModelProvider.future), isNull);
  });

  test('choosing a folder remembers it and shows it', () async {
    final preference = FakePreference();
    final picker = FakeFolderPicker('/chosen');
    final c = makeContainer(picker, preference);
    await c.read(outputFolderViewModelProvider.future);

    await c.read(outputFolderViewModelProvider.notifier).choose();

    expect(c.read(outputFolderViewModelProvider).value, '/chosen');
    expect(preference.value, '/chosen');
  });

  test('the dialog starts in the current folder, and cancelling changes nothing',
      () async {
    final preference = FakePreference('/current');
    final picker = FakeFolderPicker(null); // the user cancels
    final c = makeContainer(picker, preference);
    await c.read(outputFolderViewModelProvider.future);

    await c.read(outputFolderViewModelProvider.notifier).choose();

    expect(picker.lastInitialDirectory, '/current');
    expect(c.read(outputFolderViewModelProvider).value, '/current');
    expect(preference.value, '/current');
  });

  test('"ask each time" forgets the folder', () async {
    final preference = FakePreference('/current');
    final c = makeContainer(FakeFolderPicker(), preference);
    await c.read(outputFolderViewModelProvider.future);

    await c.read(outputFolderViewModelProvider.notifier).askEachTime();

    expect(c.read(outputFolderViewModelProvider).value, isNull);
    expect(preference.value, isNull);
  });
}
