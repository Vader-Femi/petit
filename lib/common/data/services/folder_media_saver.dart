import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/folder_picker.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/common/domain/services/output_folder_preference.dart';
import 'package:petit/core/utils/unique_path.dart';

/// Desktop saver: copies results into a folder.
///
/// If the user has chosen a folder (the "Save to" setting) and it can still be
/// written to, it is used without asking. Otherwise a folder dialog opens at
/// the start of the job. A remembered folder can stop working, for example
/// inside the macOS sandbox after a restart, which only keeps access to
/// folders chosen in a dialog during the current run; then the dialog opens
/// again and the new choice is remembered.
class FolderMediaSaver implements MediaSaver {
  FolderMediaSaver(this._picker, this._preference);

  final FolderPicker _picker;
  final OutputFolderPreference _preference;

  String? _lastFolder;
  Directory? _folder;

  @override
  Future<void> prepare() async {
    final saved = await _preference.read();

    if (saved != null && await _canWriteTo(saved)) {
      _folder = Directory(saved);
      return;
    }

    final chosen = await _picker.pickFolder(initialDirectory: saved ?? _lastFolder);
    if (chosen == null) {
      throw const MediaException('No output folder selected.');
    }

    _lastFolder = chosen;
    _folder = Directory(chosen);

    // The remembered folder was unusable: remember the new one instead.
    if (saved != null) {
      await _preference.write(chosen);
    }
  }

  Future<bool> _canWriteTo(String path) async {
    try {
      await Directory(path).create(recursive: true);
      final probe = File(p.join(path, '.petit_write_test'));
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<void> saveImage(String path) => _copyIntoFolder(path);

  @override
  Future<void> saveVideo(String path) => _copyIntoFolder(path);

  Future<void> _copyIntoFolder(String sourcePath) async {
    final folder = _folder;
    if (folder == null) {
      throw const MediaException('No output folder selected.');
    }
    await folder.create(recursive: true);
    final target = uniquePath(folder.path, p.basename(sourcePath));
    await File(sourcePath).copy(target);
  }

  @override
  String? get destinationFolder => _folder?.path;

  @override
  String get imageDestinationLabel => _folder?.path ?? 'the folder you choose';

  @override
  String get videoDestinationLabel => _folder?.path ?? 'the folder you choose';
}
