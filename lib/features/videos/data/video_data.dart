import 'dart:io';
import 'package:flutter_super/flutter_super.dart';

class VideoData {
  final File videoFile;
  final int? pixelWidth;
  final int? pixelHeight;
  final String? videoCodec;
  final int? frameRate;

  const VideoData({
    required this.videoFile,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.videoCodec,
    required this.frameRate,
  });

  VideoData copyWith(
      {File? videoFile, int? pixelWidth, int? pixelHeight, String? videoCodec, int? frameRate}) {
    return VideoData(
      videoFile: videoFile ?? this.videoFile,
      pixelWidth: pixelWidth ?? this.pixelWidth,
      pixelHeight: pixelHeight ?? this.pixelHeight,
      videoCodec: videoCodec ?? this.videoCodec,
      frameRate: frameRate ?? this.frameRate,
    );
  }

  @override
  List<Object?> get props => [videoFile, pixelHeight, pixelWidth, frameRate];
}
