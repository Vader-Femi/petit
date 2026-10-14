/// Works out how long a job has left from how far along it is.
///
/// Plain Dart: the clock is injected so it can be tested. Early readings are
/// too noisy to show (a job that is 1% done after one second says little), so
/// [remaining] stays null until the job is a few percent in and has run for a
/// few seconds. After that each reading is blended with the earlier ones, so
/// the number does not jump around.
class ProgressEta {
  ProgressEta({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Smallest fraction done before an estimate is made.
  static const double minFraction = 0.03;

  /// Shortest running time before an estimate is made.
  static const Duration minElapsed = Duration(seconds: 3);

  /// Weight of the newest reading when blending (0..1).
  static const double _newWeight = 0.3;

  final DateTime Function() _now;
  DateTime? _startedAt;
  Duration? _remaining;

  /// Time left, or null while it is too early to tell.
  Duration? get remaining => _remaining;

  /// Starts the clock and forgets any earlier readings.
  void start() {
    _startedAt = _now();
    _remaining = null;
  }

  /// Records that the job is [fraction] (0..1) done.
  void update(double fraction) {
    final startedAt = _startedAt;
    if (startedAt == null) return;

    final done = fraction.clamp(0.0, 1.0).toDouble();
    if (done >= 1.0) {
      _remaining = Duration.zero;
      return;
    }

    final elapsed = _now().difference(startedAt);
    if (done < minFraction || elapsed < minElapsed) return;

    final raw = elapsed.inMicroseconds * (1 - done) / done;
    final previous = _remaining;
    final blended = previous == null
        ? raw
        : previous.inMicroseconds * (1 - _newWeight) + raw * _newWeight;
    _remaining = Duration(microseconds: blended.round());
  }

  /// Forgets everything; [remaining] is null again.
  void reset() {
    _startedAt = null;
    _remaining = null;
  }
}
