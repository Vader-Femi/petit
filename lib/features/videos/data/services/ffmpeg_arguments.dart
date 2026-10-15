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
///
/// With a [hardwareEncoder] (e.g. `h264_videotoolbox`) the video goes through
/// the device's video hardware: that needs a bitrate ([videoBitrateKbps]), as
/// hardware encoders have no CRF and no x264-style presets.
List<String> buildVideoArguments({
  required String inputPath,
  required String outputPath,
  required String videoCodec,
  required int crf,
  required String preset,
  int? videoBitrateKbps,
  int? maxShortSide,
  String? hardwareEncoder,
  int? startMs,
  int? limitMs,
}) {
  // Only a stretch of the video (a sample): where it starts and how long it
  // lasts, as input options so FFmpeg does not read the rest.
  final stretch = [
    if (startMs != null) ...['-ss', _seconds(startMs)],
    if (limitMs != null) ...['-t', _seconds(limitMs)],
  ];

  if (hardwareEncoder != null) {
    if (videoBitrateKbps == null) {
      throw ArgumentError.value(
          videoBitrateKbps, 'videoBitrateKbps', 'hardware encoding needs a bitrate');
    }
    return [
      ...stretch,
      '-i',
      inputPath,
      '-vcodec',
      hardwareEncoder,
      '-b:v',
      '${videoBitrateKbps}k',
      '-maxrate',
      '${(videoBitrateKbps * 1.5).round()}k',
      '-bufsize',
      '${videoBitrateKbps * 2}k',
      // Apple's players only accept HEVC in MP4 under this tag.
      if (hardwareEncoder.startsWith('hevc_')) ...['-tag:v', 'hvc1'],
      if (maxShortSide != null) ...['-vf', ffmpegScaleFilter(maxShortSide)],
      outputPath,
    ];
  }

  return [
    ...stretch,
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

String _seconds(int ms) => (ms / 1000).toStringAsFixed(3);

/// The FFmpeg command line that tries [encoder] on one second of test video
/// and throws the result away. Success means this machine can really use it
/// (an encoder can be built in without the hardware being there).
List<String> buildHardwareProbeArguments(String encoder) => [
      '-hide_banner',
      '-f',
      'lavfi',
      '-i',
      'testsrc2=duration=1:size=640x360:rate=15',
      '-vcodec',
      encoder,
      '-b:v',
      '1000k',
      '-f',
      'null',
      '-',
    ];
