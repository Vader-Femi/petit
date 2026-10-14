import 'package:flutter/material.dart';
import 'package:petit/core/utils/format_eta.dart';

/// Full-area overlay shown while files are loading or compressing: a ring with
/// the percentage, what is happening, the time left, and a reminder to keep
/// the app open. Blocks taps on what is underneath.
///
/// Leave [percent] null for work with no measurable progress (loading files);
/// the ring then spins.
class CompressionProgressView extends StatelessWidget {
  const CompressionProgressView({
    super.key,
    required this.title,
    this.percent,
    this.detail,
    this.eta,
    this.showEta = false,
    this.keepOpenHint = false,
  });

  /// "Compressing video", "Loading images", ...
  final String title;

  /// 0..100, or null for an endless spinner.
  final int? percent;

  /// A second line, e.g. "Image 3 of 8".
  final String? detail;

  /// Time left, once known.
  final Duration? eta;

  /// Show a time-left line ("Estimating time..." until [eta] is known). Off
  /// for jobs too short for it to mean anything.
  final bool showEta;

  /// Remind the user to keep the app open.
  final bool keepOpenHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = percent == null ? null : (percent! / 100).clamp(0.0, 1.0);

    return Positioned.fill(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: percent == null ? title : '$title, $percent percent',
        child: AbsorbPointer(
          child: ColoredBox(
            color: scheme.surface.withValues(alpha: 0.94),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: value,
                              strokeWidth: 14,
                              strokeCap: StrokeCap.round,
                              backgroundColor:
                                  scheme.surfaceContainerHighest,
                            ),
                          ),
                          if (percent != null)
                            Text(
                              '$percent%',
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge,
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detail!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                    if (showEta) ...[
                      const SizedBox(height: 12),
                      Text(
                        eta == null ? 'Estimating time...' : formatEta(eta!),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (keepOpenHint) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Please keep the app open while compressing',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
