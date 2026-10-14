/// Keeps the app running while a compression continues in the background,
/// and shows the user that it is working (a notification on Android).
///
/// Only Android needs this. Elsewhere the implementation does nothing: desktop
/// apps keep running, and iOS does not allow long background work.
abstract interface class BackgroundKeepAlive {
  /// Asks to be allowed to show the notification. Returns true when allowed,
  /// or when no permission is needed. Working in the background does not
  /// depend on the answer; only whether the user sees the notification.
  Future<bool> requestNotificationPermission();

  /// Starts keeping the app alive, with [title] and [text] on the notification.
  Future<void> start({required String title, required String text});

  /// Updates the notification: progress bar at [percent] (0..100) and [text].
  Future<void> update({required int percent, required String text});

  /// Stops keeping the app alive and removes the notification.
  Future<void> stop();
}
