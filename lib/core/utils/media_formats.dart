/// File-extension checks. Anchored to the end of the path and case-insensitive,
/// unlike the old unescaped-dot regexes (where `.` matched any character).
final _imageSizeGetterFormats =
    RegExp(r'\.(png|webp|jpe?g|gif|bmp)$', caseSensitive: false);
final _heifFormats = RegExp(r'\.(heic|heif)$', caseSensitive: false);
final _jpegFormats = RegExp(r'\.jpe?g$', caseSensitive: false);
final _pngFormats = RegExp(r'\.png$', caseSensitive: false);
final _webpFormats = RegExp(r'\.webp$', caseSensitive: false);
final _compressibleImageFormats =
    RegExp(r'\.(png|webp|jpe?g|heic|heif)$', caseSensitive: false);

/// Formats `image_size_getter` can read directly.
bool isImageSizeGetterSupported(String path) =>
    _imageSizeGetterFormats.hasMatch(path);

bool isHeif(String path) => _heifFormats.hasMatch(path);

bool isJpeg(String path) => _jpegFormats.hasMatch(path);

bool isPng(String path) => _pngFormats.hasMatch(path);

bool isWebp(String path) => _webpFormats.hasMatch(path);

/// Formats that can contain transparent pixels (JPEG and HEIC photos cannot,
/// in practice). Whether an image really uses transparency is checked by
/// decoding it.
bool canHaveTransparency(String path) => isPng(path) || isWebp(path);

final _videoFormats =
    RegExp(r'\.(mp4|mov|m4v|mkv|avi|webm|3gp)$', caseSensitive: false);

bool isVideoFile(String path) => _videoFormats.hasMatch(path);

/// Formats the image compressor accepts as input.
bool isCompressibleImage(String path) =>
    _compressibleImageFormats.hasMatch(path);
