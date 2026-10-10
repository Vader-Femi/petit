import 'dart:io';

/// Produces a still image for a video (used where playback is unavailable).
abstract interface class VideoThumbnailer {
  /// A still frame of [video] as an image file, or null if none could be made.
  /// The caller owns the returned file and should delete it when done.
  Future<File?> thumbnail(File video);
}
