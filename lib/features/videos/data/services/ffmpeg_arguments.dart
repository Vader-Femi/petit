// Pure Dart (no plugins), so the command lines can be unit tested.

/// FFmpeg filter that scales a video so its *shorter* side is [shortSide]
/// pixels, keeping the aspect ratio and even dimensions. It decides landscape
/// or portrait from the frame itself, so phone videos that are stored rotated
/// come out right. Commas are escaped for FFmpeg's filter syntax.
String ffmpegScaleFilter(int shortSide) =>
    'scale=w=if(gt(iw\\,ih)\\,-2\\,$shortSide):h=if(gt(iw\\,ih)\\,$shortSide\\,-2)';

/// The FFmpeg command line (without the program name) for one compression.
///
/// A list, not one string, so paths with spaces work on every OS. Rate control
/// is either constant quality ([crf]) or, when [videoBitrateKbps] is given, a
/// target bitrate with a cap and a buffer so the size stays predictable.
List<String> buildVideoArguments({
  required String inputPath,
  required String outputPath,
  required String videoCodec,
  required int crf,
  required String preset,
  int? videoBitrateKbps,
  int? maxShortSide,
}) {
  return [
    '-i',
    inputPath,
    '-vcodec',
    videoCodec,
    if (videoBitrateKbps != null) ...[
      '-b:v',
      '${videoBitrateKbps}k',
      '-maxrate',
      '${(videoBitrateKbps * 1.5).round()}k',
      '-bufsize',
      '${videoBitrateKbps * 2}k',
    ] else ...[
      '-crf',
      '$crf',
    ],
    '-preset',
    preset,
    if (maxShortSide != null) ...['-vf', ffmpegScaleFilter(maxShortSide)],
    outputPath,
  ];
}
