import 'package:flutter/material.dart';
import 'package:petit/common/data/summary_report.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/images/presentation/widget/summary_row.dart';

/// Shows the result of a compression job. Shared by the pages and the
/// keyboard shortcuts so both open the same dialog.
void showCompressionSummaryDialog({
  required BuildContext context,
  required SummaryReport summaryReport,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => CompressionSummaryDialog(summaryReport: summaryReport),
  );
}

class CompressionSummaryDialog extends StatelessWidget {
  const CompressionSummaryDialog({super.key, required this.summaryReport});

  final SummaryReport summaryReport;

  @override
  Widget build(BuildContext context) {
    final percentSaved = (summaryReport.savedPercent * 100).toStringAsFixed(1);
    final theme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actionsPadding: const EdgeInsets.only(right: 16, bottom: 12),
      title: Text(
        'Compression Summary',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: theme.primary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          SummaryRow(label: 'Original Size', value: summaryReport.originalSizeBytes),
          SummaryRow(label: 'Compressed Size', value: summaryReport.compressedSizeBytes),
          SummaryRow(label: 'Saved', value: summaryReport.savedBytes),
          SummaryRow(label: 'Saved to', value: summaryReport.path),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Space Saved: $percentSaved%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: summaryReport.savedPercent,
              minHeight: 14,
              backgroundColor: theme.primaryContainer.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation(theme.primary),
            ),
          ),
        ],
      ),
      actions: [
        // Desktop: show the saved files in Finder / Explorer / the file manager.
        if (PlatformInfo.isDesktop && summaryReport.folderPath != null)
          TextButton(
            onPressed: () => launchUrl(Uri.directory(summaryReport.folderPath!)),
            child: Text(
              'Open folder',
              style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Close",
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
