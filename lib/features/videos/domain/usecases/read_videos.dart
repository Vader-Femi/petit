import 'dart:io';

import 'package:petit/features/videos/domain/entities/video_data.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';

/// Turns video file paths (picked, dropped, or shared) into [VideoData] with
/// their probed properties (dimensions, codec, framerate, duration) and file size.
class ReadVideosUseCase {
  ReadVideosUseCase(this._compressor);

  final VideoCompressor _compressor;

  Future<List<VideoData>> call(List<String> paths) async {
    final list = <VideoData>[];
    for (final path in paths) {
      final file = File(path);
      VideoData data;
      try {
        data = await _compressor.probe(file);
      } catch (_) {
        data = VideoData(
          videoFile: file,
          pixelWidth: null,
          pixelHeight: null,
          videoCodec: null,
          frameRate: null,
        );
      }
      final bytes = await file.length();
      list.add(data.copyWith(fileBytes: bytes));
    }
    return list;
  }
}
