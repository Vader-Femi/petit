import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:petit/features/videos/domain/services/video_compressor.dart';
import 'package:petit/features/videos/domain/services/video_thumbnailer.dart';
import 'package:petit/features/videos/presentation/preview/video_preview.dart';

/// A still frame instead of playback, for platforms where `video_player` has
/// no implementation (Windows, Linux).
class ThumbnailVideoPreview implements VideoPreview {
  ThumbnailVideoPreview(this._video, this._compressor, this._thumbnailer);

  final File _video;
  final VideoCompressor _compressor;
  final VideoThumbnailer _thumbnailer;

  File? _thumbnail;
  Duration _duration = Duration.zero;
  double _aspectRatio = 16 / 9;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    final data = await _compressor.probe(_video);

    final width = data.pixelWidth;
    final height = data.pixelHeight;
    if (width != null && height != null && height > 0) {
      _aspectRatio = width / height;
    }
    _duration = Duration(milliseconds: data.durationMs ?? 0);

    final thumbnail = await _thumbnailer.thumbnail(_video);
    if (thumbnail != null) {
      _thumbnail = thumbnail;
      // The thumbnail is already upright (FFmpeg applies rotation metadata),
      // so its own size gives the right aspect ratio.
      try {
        final size = ImageSizeGetter.getSizeResult(FileInput(thumbnail)).size;
        if (size.height > 0) _aspectRatio = size.width / size.height;
      } catch (_) {
        // Keep the ratio from the probe.
      }
    }
    _initialized = true;
  }

  @override
  bool get isInitialized => _initialized;

  @override
  Duration get duration => _duration;

  @override
  double get aspectRatio => _aspectRatio;

  @override
  bool get canPlay => false;

  @override
  bool get isPlaying => false;

  @override
  Future<void> togglePlayback() async {}

  @override
  Widget build(BuildContext context) {
    final thumbnail = _thumbnail;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnail != null)
          Image.file(thumbnail, fit: BoxFit.cover)
        else
          const ColoredBox(
            color: Colors.black12,
            child: Center(child: Icon(Icons.movie_outlined, size: 48)),
          ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Preview image. Playback is not available on this platform.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    final thumbnail = _thumbnail;
    _thumbnail = null;
    if (thumbnail != null) {
      thumbnail.delete().then((_) {}, onError: (_) {});
    }
  }
}
