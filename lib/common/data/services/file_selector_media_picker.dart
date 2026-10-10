import 'package:file_selector/file_selector.dart';
import 'package:petit/common/domain/services/media_picker.dart';

/// Desktop picker using the operating system's file dialog.
class FileSelectorMediaPicker implements MediaPicker {
  // Upper-case variants too: some platforms match extensions case-sensitively.
  static List<String> _withUpperCase(List<String> extensions) =>
      [...extensions, ...extensions.map((e) => e.toUpperCase())];

  static final _imageTypes = XTypeGroup(
    label: 'Images',
    extensions: _withUpperCase(['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif']),
  );

  static final _videoTypes = XTypeGroup(
    label: 'Videos',
    extensions:
        _withUpperCase(['mp4', 'mov', 'm4v', 'mkv', 'avi', 'webm', '3gp']),
  );

  @override
  Future<List<String>> pickImages() async {
    final files = await openFiles(acceptedTypeGroups: [_imageTypes]);
    return files.map((file) => file.path).toList();
  }

  @override
  Future<String?> pickVideo() async {
    final file = await openFile(acceptedTypeGroups: [_videoTypes]);
    return file?.path;
  }
}
