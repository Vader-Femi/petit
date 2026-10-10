import 'package:image_picker/image_picker.dart';
import 'package:petit/common/domain/services/media_picker.dart';

class ImagePickerMediaPicker implements MediaPicker {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<List<String>> pickImages() async {
    final files = await _picker.pickMultiImage();
    return files.map((file) => file.path).toList();
  }

  @override
  Future<String?> pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    return file?.path;
  }
}
