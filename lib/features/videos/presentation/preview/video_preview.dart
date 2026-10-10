import 'package:flutter/widgets.dart';

/// What the video page needs from a preview, independent of the plugin behind
/// it: `video_player` where it works, a still frame where it does not.
abstract interface class VideoPreview {
  Future<void> initialize();

  bool get isInitialized;

  Duration get duration;

  double get aspectRatio;

  /// Whether the preview can play. When false the page hides play/pause.
  bool get canPlay;

  bool get isPlaying;

  Future<void> togglePlayback();

  Widget build(BuildContext context);

  void dispose();
}
