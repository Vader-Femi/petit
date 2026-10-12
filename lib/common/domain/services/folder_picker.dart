/// Lets the user choose a folder (a native dialog on desktop).
abstract interface class FolderPicker {
  /// The chosen folder, or null if the user cancelled.
  Future<String?> pickFolder({String? initialDirectory});
}
