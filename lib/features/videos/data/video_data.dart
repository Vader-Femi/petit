import 'dart:io';
import 'package:flutter_super/flutter_super.dart';

class VideoData with SuperModel {
  final File videoFile;
  final int? pixelWidth;
  final int? pixelHeight;
  final int? frameRate;

  const VideoData({
    required this.videoFile,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.frameRate,
  });

  VideoData copyWith(
      {File? videoFile, int? pixelWidth, int? pixelHeight, int? frameRate}) {
    return VideoData(
      videoFile: videoFile ?? this.videoFile,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
      frameRate: frameRate ?? this.frameRate,
    );
  }

  @override
  List<Object?> get props => [videoFile, pixelHeight, pixelWidth, frameRate];
}
