import 'dart:io';

import 'package:petit/features/images/domain/services/image_previewer.dart';

/// Phones can draw HEIC themselves, so the original is shown as it is.
class NoopImagePreviewer implements ImagePreviewer {
  @override
  Future<File?> createPreview(String path) async => null;
}
