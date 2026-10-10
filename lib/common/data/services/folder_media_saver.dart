import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:petit/common/domain/media_exception.dart';
import 'package:petit/common/domain/services/media_saver.dart';
import 'package:petit/core/utils/unique_path.dart';

/// Desktop saver: copies results into a folder the user picks at the start of
/// each job. Asking each time also works inside the macOS sandbox, which only
/// grants access to folders chosen in a dialog.
class FolderMediaSaver implements MediaSaver {
  String? _lastFolder;
  Directory? _folder;

  @override
  Future<void> prepare() async {
    final path = await getDirectoryPath(
      initialDirectory: _lastFolder,
      confirmButtonText: 'Save here',
    );
    if (path == null) {
      throw const MediaException('No output folder selected.');
    }
    _lastFolder = path;
    _folder = Directory(path);
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
  String get imageDestinationLabel => _folder?.path ?? 'the folder you choose';

  @override
  String get videoDestinationLabel => _folder?.path ?? 'the folder you choose';
}
