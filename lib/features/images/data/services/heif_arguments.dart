// Pure Dart (no plugins), so the command line can be unit tested.

/// The FFmpeg command line (without the program name) that turns the first
/// image of a HEIC/HEIF file into a high quality JPEG.
///
/// With [maxLongSide] the picture is scaled down so its longer side has at
/// most that many pixels (never enlarged), which is what a preview needs.
/// FFmpeg applies the file's rotation itself. Commas are escaped for FFmpeg's
/// filter syntax.
List<String> buildHeifToJpegArguments({
  required String inputPath,
  required String outputPath,
  int? maxLongSide,
}) {
  return [
    '-y',
    '-i',
    inputPath,
    '-frames:v',
    '1',
    if (maxLongSide != null) ...[
      '-vf',
      'scale=w=if(gt(iw\\,ih)\\,min(iw\\,$maxLongSide)\\,-2)'
          ':h=if(gt(iw\\,ih)\\,-2\\,min(ih\\,$maxLongSide))',
    ],
    '-q:v',
    '2',
    outputPath,
  ];
}
