import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// True when [image] has at least one pixel that is not fully opaque.
///
/// An image can carry an alpha channel and still be fully opaque (most
/// screenshots do), so the channel count alone is not enough.
bool imageHasTransparency(img.Image image) {
  if (!image.hasAlpha && !image.hasPalette) return false;
  for (final pixel in image) {
    if (pixel.aNormalized < 1.0) return true;
  }
  return false;
}

/// A copy of [image] on a white background without an alpha channel, which is
/// what JPEG needs. Without this, transparent areas become whatever colour
/// happens to be stored under them (often black).
img.Image flattenOnWhite(img.Image image) {
  final withAlpha = image.convert(numChannels: 4);
  final background = img.Image(
    width: image.width,
    height: image.height,
    numChannels: 3,
  )..clear(img.ColorRgb8(255, 255, 255));
  return img.compositeImage(background, withAlpha);
}

/// Decodes the file at [path] in a background isolate and reports whether it
/// has transparent pixels. Unreadable files count as opaque.
Future<bool> hasTransparentPixels(String path) =>
    Isolate.run(() => _hasTransparentPixelsSync(path));

bool _hasTransparentPixelsSync(String path) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  return decoded != null && imageHasTransparency(decoded);
}

/// Decodes the file at [path], puts it on white and returns JPEG bytes at
/// maximum quality (a later step lowers the quality), in a background isolate.
Future<Uint8List> flattenToJpegBytes(String path) =>
    Isolate.run(() => _flattenToJpegBytesSync(path));

Uint8List _flattenToJpegBytesSync(String path) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) {
    throw const FormatException('Could not read this image.');
  }
  final flat = imageHasTransparency(decoded) ? flattenOnWhite(decoded) : decoded;
  return img.encodeJpg(flat, quality: 100);
}
