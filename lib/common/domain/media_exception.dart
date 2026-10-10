/// A failure whose [message] is safe to show to the user.
class MediaException implements Exception {
  final String message;

  const MediaException(this.message);

  @override
  String toString() => message;
}
