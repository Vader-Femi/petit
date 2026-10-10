/// Saves finished files where the user can find them (gallery on mobile,
/// a chosen folder on desktop).
abstract interface class MediaSaver {
  /// Called once before a job starts. Implementations that need to know where
  /// to save (e.g. desktop) ask the user here. Throws a [MediaException] if the
  /// user declines, so no work is done for nothing.
  Future<void> prepare();

  Future<void> saveImage(String path);

  Future<void> saveVideo(String path);

  /// Human readable location shown in the summary dialog.
  String get imageDestinationLabel;

  String get videoDestinationLabel;
}
