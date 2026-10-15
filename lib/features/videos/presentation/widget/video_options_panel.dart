import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/common/widgets/save_to_tile.dart';
import 'package:petit/common/widgets/slider_box.dart';
import 'package:petit/common/widgets/target_size_field.dart';
import 'package:petit/core/utils/format_bytes.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/videos/domain/usecases/estimate_video_size.dart';
import 'package:petit/features/videos/domain/video_warnings.dart';
import 'package:petit/features/videos/presentation/state/video_presets.dart';
import 'package:petit/features/videos/presentation/state/videos_state.dart';
import 'package:petit/features/videos/presentation/state/videos_viewmodel.dart';

/// Everything that decides how a video is compressed: quality or target size,
/// resolution, encoding speed, and (desktop) where the result is saved.
class VideoOptionsPanel extends ConsumerWidget {
  const VideoOptionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(videosViewModelProvider);
    final viewModel = ref.read(videosViewModelProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<VideoMode>(
            segments: const [
              ButtonSegment(
                value: VideoMode.quality,
                label: Text('Quality'),
                icon: Icon(Icons.tune),
              ),
              ButtonSegment(
                value: VideoMode.targetSize,
                label: Text('Target size'),
                icon: Icon(Icons.straighten),
              ),
            ],
            selected: {state.mode},
            onSelectionChanged: (selection) => viewModel.setMode(selection.first),
          ),
        ),
        const SizedBox(height: 12),
        if (state.mode == VideoMode.quality)
          _qualityBox(context, state, viewModel)
        else
          _targetSizeBox(context, state, viewModel),
        const SizedBox(height: 12),
        _resolutionBox(context, state, viewModel),
        const SizedBox(height: 12),
        // Only offered when this machine has video hardware that works.
        if (state.fastEncodingAvailable) ...[
          _encodingBox(context, state, viewModel),
          const SizedBox(height: 12),
        ],
        // Presets are for the software encoder; the hardware has none.
        if (!state.usesFastEncoding) _speedBox(context, state, viewModel),
        _EstimateBox(state: state, viewModel: viewModel),
        _WarningBox(warnings: state.warnings),
        const SaveToTile(),
      ],
    );
  }

  Widget _encodingBox(
    BuildContext context,
    VideosState state,
    VideosViewModel viewModel,
  ) {
    return _OptionBox(
      title: 'Encoding',
      note: state.fastEncoding
          ? 'Much faster, but files come out somewhat bigger, and a target '
              'size is less exact. If it does not work on your device, Petit '
              'switches back by itself.'
          : 'Best compression: smaller files, but it takes longer.',
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Fast encoding'),
        subtitle: const Text("Use your device's video hardware"),
        value: state.fastEncoding,
        onChanged: viewModel.setFastEncoding,
      ),
    );
  }

  Widget _qualityBox(
      BuildContext context, VideosState state, VideosViewModel viewModel) {
    return buildSliderBox(
      context: context,
      label: "Compression Level",
      minValue: labelForCrfSlider(0),
      maxValue: labelForCrfSlider(100),
      tootTipMessage: "Adjusts the compression level.\n"
          "•${labelForCrfSlider(100)} = smallest size, less clarity\n"
          "•${labelForCrfSlider(0)} = smaller size, more clarity\n"
          "•Recommended = ${labelForCrfSlider(80)}",
      slider: Slider(
        value: state.crfQuality / 100,
        min: 0,
        max: 1,
        divisions: 4,
        label: "${labelForCrfSlider(state.crfQuality)} Compression",
        onChanged: viewModel.updateCfrQualitySlider,
      ),
    );
  }

  Widget _targetSizeBox(
      BuildContext context, VideosState state, VideosViewModel viewModel) {
    final bytes = state.videoBytes;
    final lengthUnknown =
        state.videoInfo != null && (state.videoInfo!.durationMs ?? 0) <= 0;

    final String note;
    if (lengthUnknown) {
      note = "This video's length could not be read, so a target size is not "
          "possible. Use Quality instead.";
    } else if (bytes != null) {
      note = "The video is ${formatBytes(bytes)}. The result will be about "
          "the chosen size, usually a little smaller.";
    } else {
      note = "The result will be about the chosen size, usually a little smaller.";
    }

    return _OptionBox(
      title: 'Target size',
      note: note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final mb in kTargetSizeOptionsMb)
                ChoiceChip(
                  label: Text('$mb MB'),
                  selected: state.targetSizeMb == mb,
                  // Sizes at or above the video's own size would not shrink it.
                  onSelected: state.canTargetMb(mb)
                      ? (_) => viewModel.setTargetSizeMb(mb)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TargetSizeField(
            valueMb: state.targetSizeMb,
            presets: kTargetSizeOptionsMb,
            onChanged: viewModel.setTargetSizeMb,
          ),
        ],
      ),
    );
  }

  Widget _resolutionBox(
      BuildContext context, VideosState state, VideosViewModel viewModel) {
    final source = state.sourceShortSide;

    return _OptionBox(
      title: 'Resolution',
      note: source == null
          ? 'Videos are only made smaller, never enlarged.'
          : "Only smaller sizes are offered; this video's shorter side is "
              "$source px.",
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final resolution in VideoResolution.values)
            ChoiceChip(
              label: Text(resolution.label),
              selected: state.resolution == resolution,
              onSelected: state.canUseResolution(resolution)
                  ? (_) => viewModel.setResolution(resolution)
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _speedBox(
      BuildContext context, VideosState state, VideosViewModel viewModel) {
    return buildSliderBox(
      context: context,
      label: "Encoding speed",
      minValue: kFfmpegPresets.first.desc,
      maxValue: kFfmpegPresets.last.desc,
      tootTipMessage: "How hard the encoder works.\n"
          "•${kFfmpegPresets.first.desc} = finishes sooner, file a bit bigger\n"
          "•${kFfmpegPresets.last.desc} = takes longer, same quality in a smaller file\n"
          "It does not set the file size: use Quality or Target size for that.",
      slider: Slider(
        value: state.presetIndex.toDouble(),
        min: 0,
        max: (kFfmpegPresets.length - 1).toDouble(),
        divisions: kFfmpegPresets.length - 1,
        label: kFfmpegPresets[state.presetIndex].desc,
        onChanged: (value) => viewModel.setPresetIndex(value.toInt()),
      ),
    );
  }
}

/// The expected size, worked out on request by compressing a few short samples
/// of the video. Hidden when the video's length is unknown (nothing to sample).
class _EstimateBox extends StatelessWidget {
  const _EstimateBox({required this.state, required this.viewModel});

  final VideosState state;
  final VideosViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final length = state.videoInfo?.durationMs ?? 0;
    if (state.videoInfo != null && length <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final estimate = state.currentEstimate;

    final Widget child;
    if (state.isEstimating) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: state.estimatePercent / 100),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text('Compressing short samples...')),
              TextButton(
                onPressed: viewModel.cancelEstimate,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      );
    } else if (estimate != null) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headline(estimate),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: estimate.isLarger
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(_detail(estimate), style: theme.textTheme.bodySmall),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: viewModel.estimateSize,
              child: const Text('Estimate again'),
            ),
          ),
        ],
      );
    } else {
      child = Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          onPressed: state.isBusy ? null : viewModel.estimateSize,
          icon: const Icon(Icons.speed),
          label: const Text('Estimate the size'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _OptionBox(
        title: 'Size estimate',
        note: estimate == null && !state.isEstimating
            ? 'Compresses a few seconds of your video with these settings to '
                'predict the result. It takes a short while.'
            : null,
        child: child,
      ),
    );
  }

  static String _headline(VideoSizeEstimate e) {
    final before = formatBytes(e.originalBytes);
    final after = formatBytes(e.estimatedBytes);
    if (e.isLarger) {
      return '$before \u2192 about $after (not smaller)';
    }
    final percent = (e.savedFraction * 100).round();
    return '$before \u2192 about $after (-$percent%)';
  }

  static String _detail(VideoSizeEstimate e) {
    if (e.isLarger) {
      return 'At these settings the video would not get smaller, so the '
          'original is kept. Try a stronger compression level.';
    }
    if (e.isExact) return 'The whole video was compressed, so this is exact.';
    return 'From ${e.sampleCount} short samples. The real size can differ by '
        'a few percent.';
  }
}

/// Warnings about choices that are unlikely to make the video smaller. Shown
/// only when there is something to say.
class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.warnings});

  final List<VideoSettingsWarning> warnings;

  @override
  Widget build(BuildContext context) {
    if (warnings.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 20, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      warning.message,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A titled box with the same look as the slider boxes.
class _OptionBox extends StatelessWidget {
  const _OptionBox({required this.title, required this.child, this.note});

  final String title;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          child,
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
