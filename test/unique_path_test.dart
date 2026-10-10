import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:petit/core/utils/unique_path.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('petit_unique_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('returns the plain name when it is free', () {
    expect(uniquePath(dir.path, 'photo.jpg'), p.join(dir.path, 'photo.jpg'));
  });

  test('adds a counter before the extension when the name is taken', () {
    File(p.join(dir.path, 'photo.jpg')).writeAsStringSync('x');
    expect(uniquePath(dir.path, 'photo.jpg'),
        p.join(dir.path, 'photo (1).jpg'));

    File(p.join(dir.path, 'photo (1).jpg')).writeAsStringSync('x');
    expect(uniquePath(dir.path, 'photo.jpg'),
        p.join(dir.path, 'photo (2).jpg'));
  });

  test('works for names without an extension and for folders', () {
    Directory(p.join(dir.path, 'clip')).createSync();
    expect(uniquePath(dir.path, 'clip'), p.join(dir.path, 'clip (1)'));
  });
}
