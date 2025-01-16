import 'dart:ffi';
import 'dart:io';

import 'package:flutter_super/flutter_super.dart';

class ImageData with SuperModel {
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

  ImageData copyWith(
      {File? imageFile, int? pixelWidth, int? pixelHeight, int? quality,}) {
    return ImageData(
      imageFile: imageFile ?? this.imageFile,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
      quality: quality ?? this.quality,
    );
  }

  @override
  List<Object?> get props => [imageFile, pixelHeight, pixelWidth, quality];
}
