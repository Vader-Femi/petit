class CodecConfig {
  final String vcodec;
  final int minCrf;
  final int maxCrf;

  CodecConfig({
    required this.vcodec,
    required this.minCrf,
    required this.maxCrf,
  });
}

CodecConfig getVcodecConfigFromCodec(String codec) {
  switch (codec.toLowerCase()) {
    case 'hevc':
    case 'h265':
      return CodecConfig(vcodec: 'libx265', minCrf: 18, maxCrf: 35);
    case 'h264':
    case 'avc1':
      return CodecConfig(vcodec: 'libx264', minCrf: 18, maxCrf: 28);
    case 'vp9':
      return CodecConfig(vcodec: 'libvpx-vp9', minCrf: 15, maxCrf: 35);
    default:
      return CodecConfig(vcodec: 'libx264', minCrf: 18, maxCrf: 28); // fallback
  }
}
