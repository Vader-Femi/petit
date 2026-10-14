/// A friendly "time left" for [remaining], e.g. `about 2 minutes left`.
///
/// Rounded on purpose: a countdown that claims to know the second is a lie.
String formatEta(Duration remaining) {
  final seconds = remaining.inSeconds;
  if (seconds < 10) return 'a few seconds left';

  if (seconds < 60) {
    final rounded = (seconds / 5).round() * 5;
    if (rounded < 60) return 'about $rounded seconds left';
    return 'about 1 minute left';
  }

  final minutes = (seconds / 60).ceil();
  if (minutes == 1) return 'about 1 minute left';
  if (minutes < 60) return 'about $minutes minutes left';

  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? 'about $hours h left' : 'about $hours h $rest min left';
}
