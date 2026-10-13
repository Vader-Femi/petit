import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/core/utils/media_formats.dart';
import 'package:petit/features/images/domain/entities/image_size_estimate.dart';
import 'package:petit/features/images/presentation/state/images_state.dart';
import 'package:petit/features/images/presentation/state/images_viewmodel.dart';

/// The expected size of the current image, plus the transparency and location
/// switches. Sits under the quality slider.
class ImageOptionsPanel extends ConsumerWidget {
  const ImageOptionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(imagesViewModelProvider);
    final viewModel = ref.read(imagesViewModelProvider.notifier);
    final image = state.currentImage;
    if (image == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final showTransparency = canHaveTransparency(image.imageFile.path);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EstimateRow(state: state),
          if (showTransparency)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Keep transparency'),
              subtitle: const Text(
                  'Transparent areas stay transparent. Off: they turn white and the image is saved as JPG.'),
              value: state.options.keepTransparency,
              onChanged: state.isBusy ? null : viewModel.setKeepTransparency,
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Remove location data'),
            subtitle: const Text(
                'Where the photo was taken. Camera and date details go too.'),
            value: state.options.removeLocation,
            onChanged: state.isBusy ? null : viewModel.setRemoveLocation,
          ),
        ],
      ),
    );
  }
}

class _EstimateRow extends StatelessWidget {
  const _EstimateRow({required this.state});

  final ImagesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estimate = state.estimate;

    if (state.isEstimating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Estimating size...'),
          ],
        ),
      );
    }

    if (estimate == null) return const SizedBox.shrink();

    final warning = estimate.keepsOriginal || estimate.isLarger;
    final color =
        warning ? theme.colorScheme.error : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.straighten,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _headline(estimate),
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
                if (_detail(estimate) case final detail?)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(detail, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _headline(ImageSizeEstimate e) {
    final before = formatBytes(e.originalBytes);
    if (e.keepsOriginal) {
      return 'Can\'t get smaller than $before';
    }
    final after = formatBytes(e.estimatedBytes);
    if (e.isLarger) {
      return '$before \u2192 about $after (larger)';
    }
    final percent = (e.savedFraction * 100).round();
    return '$before \u2192 about $after (-$percent%) \u00b7 ${e.formatLabel}';
  }

  static String? _detail(ImageSizeEstimate e) {
    if (e.keepsOriginal) {
      return 'At this quality the result would not be smaller, so the '
          'original is saved unchanged. Try a lower quality.';
    }
    if (e.isLarger) {
      return 'It is saved anyway because location data is being removed.';
    }
    if (e.isPng) {
      return 'Saved as PNG to keep the transparency, so the quality slider '
          'has little effect here.';
    }
    return null;
  }
}
