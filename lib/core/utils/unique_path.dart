import 'dart:io';

import 'package:path/path.dart' as p;

/// A path inside [directory] for a file called [fileName] that does not exist
/// yet: `photo.jpg`, then `photo (1).jpg`, `photo (2).jpg`, ...
String uniquePath(String directory, String fileName) {
  final base = p.basenameWithoutExtension(fileName);
  final extension = p.extension(fileName);

  var candidate = p.join(directory, fileName);
  var counter = 1;
  while (File(candidate).existsSync() || Directory(candidate).existsSync()) {
    candidate = p.join(directory, '$base ($counter)$extension');
    counter++;
  }
  return candidate;
}
