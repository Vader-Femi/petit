import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'platform_utils.dart';

const _workDirName = 'petit_work';

/// Folder owned by Petit for intermediate and output files.
///
/// Never write next to the user's original files, and never delete outside
/// this folder on desktop: there the system temp directory is shared with
/// other applications.
Future<Directory> getWorkDir() async {
  final temp = await getTemporaryDirectory();
  final dir = Directory(p.join(temp.path, _workDirName));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Folder for video preview thumbnails. Kept apart from the work folder so
/// finishing an image job cannot delete a preview the video tab is showing.
Future<Directory> getPreviewDir() async {
  final temp = await getTemporaryDirectory();
  final dir = Directory(p.join(temp.path, 'petit_preview'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Creates a fresh sub-folder for a single compression job, so files inside
/// can keep clean names (e.g. `photo_compressed.jpg`) without colliding.
Future<Directory> createJobDir() async {
  final work = await getWorkDir();
  final dir = Directory(
    p.join(work.path, DateTime.now().microsecondsSinceEpoch.toString()),
  );
  return dir.create(recursive: true);
}

/// Removes temporary files created while compressing.
///
/// Mobile: the temp directory is the app's private cache, so it is cleared
/// completely (same as the previous behaviour).
/// Desktop: only Petit's own work folder is cleared.
Future<void> clearTempFiles() async {
  try {
    final temp = await getTemporaryDirectory();
    if (!await temp.exists()) return;

    if (PlatformInfo.isMobile) {
      await _deleteChildren(temp);
    } else {
      final work = Directory(p.join(temp.path, _workDirName));
      if (await work.exists()) {
        await _deleteChildren(work);
      }
    }
    debugPrint('Temp files cleared');
  } catch (e) {
    debugPrint('Error clearing temp files: $e');
  }
}

Future<void> _deleteChildren(Directory dir) async {
  for (final entity in dir.listSync()) {
    try {
      await entity.delete(recursive: true);
    } catch (e) {
      debugPrint('Failed to delete ${entity.path}: $e');
    }
  }
}
