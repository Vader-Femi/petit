import 'package:petit/common/domain/services/background_keep_alive.dart';

/// For platforms that need no help to keep working (desktop), or cannot do
/// long background work (iOS).
class NoopBackgroundKeepAlive implements BackgroundKeepAlive {
  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> start({required String title, required String text}) async {}

  @override
  Future<void> update({required int percent, required String text}) async {}

  @override
  Future<void> stop() async {}
}
