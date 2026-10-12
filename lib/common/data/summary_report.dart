class SummaryReport {
  final String originalSizeBytes;
  final String compressedSizeBytes;
  final String savedBytes;
  final double savedPercent;
  final String path;

  /// A folder the user can open from the summary, when there is one (desktop).
  final String? folderPath;

  const SummaryReport({
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.savedBytes,
    required this.savedPercent,
    required this.path,
    this.folderPath,
  });
}
