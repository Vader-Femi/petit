import 'package:flutter/services.dart';
import 'package:petit/common/domain/services/background_keep_alive.dart';

/// Talks to `CompressionService` in the Android project, a foreground service
/// with a progress notification and a wake lock (see MainActivity.kt).
class AndroidBackgroundKeepAlive implements BackgroundKeepAlive {
  AndroidBackgroundKeepAlive([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'com.outsidetheide.petit/keep_alive';

  final MethodChannel _channel;

  @override
  Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ??
      false;

  @override
  Future<void> start({required String title, required String text}) =>
      _channel.invokeMethod<void>('start', {'title': title, 'text': text});

  @override
  Future<void> update({required int percent, required String text}) =>
      _channel.invokeMethod<void>(
          'update', {'percent': percent, 'text': text});

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
}
