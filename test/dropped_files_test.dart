import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:petit/core/utils/dropped_files.dart';

void main() {
  group('classifyDroppedFiles', () {
    test('sorts images, videos and everything else', () {
      final media = classifyDroppedFiles([
        '/a/photo.JPG',
        '/a/shot.heic',
        '/a/clip.MP4',
        '/a/movie.mkv',
        '/a/notes.txt',
        '/a/animation.gif',
      ]);

      expect(media.images, ['/a/photo.JPG', '/a/shot.heic']);
      expect(media.videos, ['/a/clip.MP4', '/a/movie.mkv']);
      expect(media.unsupported, ['/a/notes.txt', '/a/animation.gif']);
      expect(media.isEmpty, isFalse);
    });

    test('is empty when nothing is usable', () {
      expect(classifyDroppedFiles(['/a/notes.txt']).isEmpty, isTrue);
      expect(classifyDroppedFiles(const []).isEmpty, isTrue);
    });
  });

  group('expandDroppedFolders', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('petit_drop_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('replaces a folder with its files, sorted, not recursive', () {
      final folder = Directory(p.join(dir.path, 'holiday'))..createSync();
      File(p.join(folder.path, 'b.jpg')).writeAsStringSync('x');
      File(p.join(folder.path, 'a.png')).writeAsStringSync('x');
      Directory(p.join(folder.path, 'nested')).createSync();
      File(p.join(folder.path, 'nested', 'c.jpg')).writeAsStringSync('x');

      expect(expandDroppedFolders([folder.path]), [
        p.join(folder.path, 'a.png'),
        p.join(folder.path, 'b.jpg'),
      ]);
    });

    test('keeps plain files and skips paths that cannot be read', () {
      final file = File(p.join(dir.path, 'one.jpg'))..writeAsStringSync('x');

      expect(
        expandDroppedFolders([file.path, p.join(dir.path, 'missing')]),
        [file.path, p.join(dir.path, 'missing')],
      );
    });
  });
}
