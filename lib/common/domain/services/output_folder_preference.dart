/// Remembers the folder results are saved to, across app launches.
abstract interface class OutputFolderPreference {
  /// The saved folder, or null when the user wants to be asked each time.
  Future<String?> read();

  /// Saves [path]; null goes back to asking each time.
  Future<void> write(String? path);
}
