/// Lets the user choose media. Implementations return plain file paths so the
/// domain layer does not depend on any picker plugin.
abstract interface class MediaPicker {
  /// Paths of the chosen images; empty if nothing was picked.
  Future<List<String>> pickImages();

  /// Path of the chosen video, or null if nothing was picked.
  Future<String?> pickVideo();
}
