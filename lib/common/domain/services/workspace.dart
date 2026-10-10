/// Owns the temporary files created while compressing.
abstract interface class Workspace {
  /// Deletes temporary files. Must never touch the user's own files.
  Future<void> clear();
}
