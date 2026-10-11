/// Human readable size, e.g. `1.50 MB`. Zero or negative sizes give `0 B`.
String formatBytes(int bytes, [int decimals = 2]) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB"];
  final i = (bytes == 0) ? 0 : (bytes.bitLength / 10).floor();
  final size = bytes / (1 << (10 * i));
  return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
}
