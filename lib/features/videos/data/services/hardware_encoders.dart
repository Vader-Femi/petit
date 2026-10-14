// Pure Dart (no plugins), so it can be unit tested.

/// Hardware encoders worth trying for [softwareCodec] (`libx264` or `libx265`,
/// as in `CodecConfig.vcodec`) on [os] (`macos`, `ios`, `android`, `windows`
/// or `linux`), best first. Empty when there is nothing to try, e.g. VP9.
///
/// Being in the list does not mean it works: FFmpeg can list an encoder that
/// needs hardware this machine lacks, so each one is tried before use.
List<String> hardwareEncoderCandidates(String softwareCodec, String os) {
  final family = switch (softwareCodec) {
    'libx264' => 'h264',
    'libx265' => 'hevc',
    _ => null,
  };
  if (family == null) return const [];

  return switch (os) {
    'macos' || 'ios' => ['${family}_videotoolbox'],
    'android' => ['${family}_mediacodec'],
    // NVIDIA, Intel, AMD, then Windows' own Media Foundation.
    'windows' => [
        '${family}_nvenc',
        '${family}_qsv',
        '${family}_amf',
        '${family}_mf',
      ],
    // VAAPI and QSV need device set-up on the command line; NVENC does not.
    'linux' => ['${family}_nvenc'],
    _ => const [],
  };
}
