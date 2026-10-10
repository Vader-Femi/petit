import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:petit/features/videos/presentation/preview/video_preview.dart';
import 'package:video_player/video_player.dart';

/// Real playback through `video_player` (Android, iOS, macOS).
class PlayerVideoPreview implements VideoPreview {
  PlayerVideoPreview(File file) : _controller = VideoPlayerController.file(file);

  final VideoPlayerController _controller;

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  bool get isInitialized => _controller.value.isInitialized;

  @override
  Duration get duration => _controller.value.duration;

  @override
  double get aspectRatio => _controller.value.aspectRatio;

  @override
  bool get canPlay => true;

  @override
  bool get isPlaying => _controller.value.isPlaying;

  @override
  Future<void> togglePlayback() =>
      isPlaying ? _controller.pause() : _controller.play();

  @override
  Widget build(BuildContext context) => VideoPlayer(_controller);

  @override
  void dispose() {
    _controller.dispose();
  }
}
