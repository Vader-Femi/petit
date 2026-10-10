/// Saves finished files where the user can find them (gallery on mobile,
/// a chosen folder on desktop).
abstract interface class MediaSaver {
  Future<void> saveImage(String path);

  Future<void> saveVideo(String path);

  /// Human readable location shown in the summary dialog.
  String get imageDestinationLabel;

  String get videoDestinationLabel;
}
