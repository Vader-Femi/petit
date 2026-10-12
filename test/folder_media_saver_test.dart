import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:petit/common/data/services/folder_media_saver.dart';
import 'package:petit/common/domain/media_exception.dart';

import 'helpers/folder_fakes.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('petit_saver_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File source(String name) =>
      File(p.join(dir.path, 'src_$name'))..writeAsStringSync('data');

  Directory folder(String name) =>
      Directory(p.join(dir.path, name))..createSync();

  test('asks where to save when nothing is remembered', () async {
    final out = folder('out');
    final picker = FakeFolderPicker(out.path);
    final preference = FakePreference();
    final saver = FolderMediaSaver(picker, preference);

    await saver.prepare();
    await saver.saveImage(source('a.jpg').path);

    expect(picker.calls, 1);
    expect(File(p.join(out.path, 'src_a.jpg')).existsSync(), isTrue);
    expect(saver.destinationFolder, out.path);
    expect(saver.imageDestinationLabel, out.path);
    expect(preference.value, isNull, reason: 'a one-off choice is not remembered');
  });

  test('uses a remembered folder without asking', () async {
    final out = folder('remembered');
    final picker = FakeFolderPicker();
    final saver = FolderMediaSaver(picker, FakePreference(out.path));

    await saver.prepare();
    await saver.saveVideo(source('clip.mp4').path);

    expect(picker.calls, 0);
    expect(File(p.join(out.path, 'src_clip.mp4')).existsSync(), isTrue);
  });

  test('creates the remembered folder if it was deleted', () async {
    final gone = p.join(dir.path, 'deleted', 'later');
    final saver = FolderMediaSaver(FakeFolderPicker(), FakePreference(gone));

    await saver.prepare();

    expect(Directory(gone).existsSync(), isTrue);
    expect(saver.destinationFolder, gone);
  });

  test('a remembered folder that cannot be used is replaced by a new choice',
      () async {
    // A path under a regular file can never be created.
    final blocker = File(p.join(dir.path, 'blocker'))..writeAsStringSync('x');
    final unusable = p.join(blocker.path, 'sub');
    final out = folder('new_choice');
    final picker = FakeFolderPicker(out.path);
    final preference = FakePreference(unusable);
    final saver = FolderMediaSaver(picker, preference);

    await saver.prepare();

    expect(picker.calls, 1);
    expect(picker.lastInitialDirectory, unusable);
    expect(saver.destinationFolder, out.path);
    expect(preference.value, out.path);
  });

  test('declining the dialog stops the job and keeps what was remembered',
      () async {
    final blocker = File(p.join(dir.path, 'blocker'))..writeAsStringSync('x');
    final unusable = p.join(blocker.path, 'sub');
    final preference = FakePreference(unusable);
    final saver = FolderMediaSaver(FakeFolderPicker(null), preference);

    await expectLater(
      saver.prepare(),
      throwsA(isA<MediaException>()
          .having((e) => e.message, 'message', 'No output folder selected.')),
    );
    expect(preference.value, unusable);
  });

  test('never overwrites an existing file', () async {
    final out = folder('out');
    File(p.join(out.path, 'src_a.jpg')).writeAsStringSync('existing');
    final saver = FolderMediaSaver(FakeFolderPicker(), FakePreference(out.path));

    await saver.prepare();
    await saver.saveImage(source('a.jpg').path);

    expect(File(p.join(out.path, 'src_a.jpg')).readAsStringSync(), 'existing');
    expect(File(p.join(out.path, 'src_a (1).jpg')).readAsStringSync(), 'data');
  });

  test('has no folder before prepare, and refuses to save', () async {
    final saver = FolderMediaSaver(FakeFolderPicker(), FakePreference());

    expect(saver.destinationFolder, isNull);
    await expectLater(
        saver.saveImage(source('a.jpg').path), throwsA(isA<MediaException>()));
  });
}
