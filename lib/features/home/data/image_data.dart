import 'dart:ffi';
import 'dart:io';

class ImageData {
  final File imageFile;
  final int pixelWidth;
  final int pixelHeight;
  final int quality;

  const ImageData({
    required this.imageFile,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.quality,
  });

}
