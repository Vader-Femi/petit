class SummaryReport {
  final String originalSizeBytes;
  final String compressedSizeBytes;
  final String savedBytes;
  final double savedPercent;
  final String path;

  const SummaryReport({
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.savedBytes,
    required this.savedPercent,
    required this.path,
  });
}
