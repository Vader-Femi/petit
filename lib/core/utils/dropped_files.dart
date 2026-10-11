import 'dart:io';

import 'package:petit/core/utils/media_formats.dart';

/// Dropped paths sorted by what the app can do with them.
class DroppedMedia {
  final List<String> images;
  final List<String> videos;
  final List<String> unsupported;

  const DroppedMedia({
    required this.images,
    required this.videos,
    required this.unsupported,
  });

  bool get isEmpty => images.isEmpty && videos.isEmpty;
}

DroppedMedia classifyDroppedFiles(Iterable<String> paths) {
  final images = <String>[];
  final videos = <String>[];
  final unsupported = <String>[];

  for (final path in paths) {
    if (isCompressibleImage(path)) {
      images.add(path);
    } else if (isVideoFile(path)) {
      videos.add(path);
    } else {
      unsupported.add(path);
    }
  }

  return DroppedMedia(images: images, videos: videos, unsupported: unsupported);
}

/// Replaces each dropped folder with the files directly inside it (not
/// recursive); plain files are kept as they are. Folders that cannot be read
/// are skipped.
List<String> expandDroppedFolders(Iterable<String> paths) {
  final result = <String>[];
  for (final path in paths) {
    try {
      if (FileSystemEntity.isDirectorySync(path)) {
        final children = Directory(path)
            .listSync(followLinks: false)
            .whereType<File>()
            .map((file) => file.path)
            .toList()
          ..sort();
        result.addAll(children);
      } else {
        result.add(path);
      }
    } catch (_) {
      // Unreadable folder (permissions, sandbox): ignore it.
    }
  }
  return result;
}
