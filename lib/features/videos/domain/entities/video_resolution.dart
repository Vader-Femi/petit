/// Output size choices. The number is the length of the video's *shorter* side,
/// so 720p means 1280x720 for a landscape video and 720x1280 for a portrait one.
enum VideoResolution {
  original(null, 'Original'),
  p1080(1080, '1080p'),
  p720(720, '720p'),
  p480(480, '480p');

  const VideoResolution(this.shortSide, this.label);

  /// Pixels of the shorter side, or null to keep the video's own size.
  final int? shortSide;
  final String label;
}
