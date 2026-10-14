import 'package:petit/common/domain/services/background_keep_alive.dart';

/// Wraps a [BackgroundKeepAlive] for one compression job at a time.
///
/// It makes the service safe to use from the ViewModels: failures never reach
/// the job (a notification problem must not stop a compression), progress
/// updates are thinned out (a notification should not be redrawn dozens of
/// times a second), and the permission is asked only once.
class JobKeepAlive {
  JobKeepAlive(
    this._service, {
    DateTime Function()? now,
    this.minUpdateGap = const Duration(seconds: 1),
  }) : _now = now ?? DateTime.now;

  final BackgroundKeepAlive _service;
  final DateTime Function() _now;

  /// Shortest time between two notification updates.
  final Duration minUpdateGap;

  bool _askedForPermission = false;
  bool _running = false;
  int? _lastPercent;
  DateTime? _lastUpdate;

  bool get isRunning => _running;

  /// Starts keeping the app alive for a job. Waits for the notification
  /// permission the first time, so the system dialog is not hidden behind the
  /// job.
  Future<void> begin({required String title, String text = 'Starting...'}) async {
    if (_running) return;

    if (!_askedForPermission) {
      _askedForPermission = true;
      try {
        await _service.requestNotificationPermission();
      } catch (_) {
        // Not being able to ask only means no notification.
      }
    }

    try {
      await _service.start(title: title, text: text);
      _running = true;
      _lastPercent = null;
      _lastUpdate = null;
    } catch (_) {
      // The job still runs; it just may be stopped if the app goes away.
    }
  }

  /// Reports progress. Skipped when the percentage has not changed, or when
  /// the last update was too recent (the final 100% always goes through).
  void progress({required int percent, required String text}) {
    if (!_running) return;

    final clamped = percent.clamp(0, 100).toInt();
    if (clamped == _lastPercent) return;

    final now = _now();
    final last = _lastUpdate;
    if (clamped < 100 && last != null && now.difference(last) < minUpdateGap) {
      return;
    }

    _lastPercent = clamped;
    _lastUpdate = now;
    _service.update(percent: clamped, text: text).catchError((_) {});
  }

  /// Ends the job's keep-alive. Safe to call when it never started or was
  /// already ended.
  Future<void> end() async {
    if (!_running) return;
    _running = false;
    try {
      await _service.stop();
    } catch (_) {
      // Nothing useful to do; the service stops with the app at the latest.
    }
  }
}
