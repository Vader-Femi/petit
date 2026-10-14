import 'dart:io';

/// Makes a picture Flutter can draw for images it cannot decode itself, such
/// as HEIC on desktop.
abstract interface class ImagePreviewer {
  /// A displayable copy of the image at [path], or null when the original can
  /// be shown as it is, or when no preview could be made.
  Future<File?> createPreview(String path);
}
