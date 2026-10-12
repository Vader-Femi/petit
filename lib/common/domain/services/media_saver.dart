/// Saves finished files where the user can find them (gallery on mobile,
/// a chosen folder on desktop).
abstract interface class MediaSaver {
  /// Called once before a job starts. Implementations that need to know where
  /// to save (e.g. desktop) ask the user here. Throws a [MediaException] if the
  /// user declines, so no work is done for nothing.
  Future<void> prepare();

  Future<void> saveImage(String path);

  Future<void> saveVideo(String path);

  /// The folder results were saved to, when there is one the user can open
  /// (desktop). Null for the gallery on mobile. Valid after [prepare].
  String? get destinationFolder;

  /// Human readable location shown in the summary dialog.
  String get imageDestinationLabel;

  String get videoDestinationLabel;
}
