import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petit/common/widgets/save_to_tile.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/features/settings/presentation/state/settings_viewmodel.dart';
import 'package:petit/features/videos/domain/entities/video_resolution.dart';
import 'package:petit/features/videos/presentation/state/video_presets.dart';
import 'package:petit/features/videos/presentation/state/videos_state.dart';

/// Default settings for images and videos (and, on desktop, where results are
/// saved). A new selection starts from these; each tab can still be changed
/// for the job at hand.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'These are the starting settings for new images and videos. '
                'You can still change them for any single job.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              _Section(
                title: 'Images',
                icon: Icons.image_outlined,
                children: [
                  _LabeledSlider(
                    label: 'Image quality',
                    valueLabel: '${settings.imageQuality}%',
                    value: settings.imageQuality / 100,
                    divisions: 99,
                    onChanged: (v) =>
                        viewModel.setImageQuality((v * 100).round()),
                    hint: 'Lower is smaller. 20% to 98% works for most photos.',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Keep transparency'),
                    subtitle: const Text(
                        'Transparent PNG and WebP images stay transparent.'),
                    value: settings.keepTransparency,
                    onChanged: viewModel.setKeepTransparency,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remove location data'),
                    subtitle: const Text(
                        'Where the photo was taken. Camera and date details go too.'),
                    value: settings.removeLocation,
                    onChanged: viewModel.setRemoveLocation,
                  ),
                ],
              ),

              _Section(
                title: 'Videos',
                icon: Icons.videocam_outlined,
                children: [
                  const _Caption('Choose the size by'),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: false, label: Text('Quality')),
                      ButtonSegment(value: true, label: Text('Target size')),
                    ],
                    selected: {settings.videoUseTargetSize},
                    onSelectionChanged: (s) =>
                        viewModel.setVideoUseTargetSize(s.first),
                  ),
                  const SizedBox(height: 12),
                  if (settings.videoUseTargetSize) ...[
                    const _Caption('Aim for about'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final mb in kTargetSizeOptionsMb)
                          ChoiceChip(
                            label: Text('$mb MB'),
                            selected: settings.videoTargetSizeMb == mb,
                            onSelected: (_) => viewModel.setVideoTargetSizeMb(mb),
                          ),
                      ],
                    ),
                  ] else
                    _LabeledSlider(
                      label: 'Compression level',
                      valueLabel: labelForCrfSlider(settings.videoQuality),
                      value: settings.videoQuality / 100,
                      divisions: 100,
                      onChanged: (v) =>
                          viewModel.setVideoQuality((v * 100).round()),
                      hint: 'Higher compresses more and gives a smaller file.',
                    ),
                  const SizedBox(height: 12),
                  const _Caption('Resolution'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in VideoResolution.values)
                        ChoiceChip(
                          label: Text(r.label),
                          selected: settings.videoResolution == r,
                          onSelected: (_) => viewModel.setVideoResolution(r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _Caption('Encoding speed'),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      for (final (i, preset) in kFfmpegPresets.indexed)
                        ButtonSegment(value: i, label: Text(preset.desc)),
                    ],
                    selected: {settings.videoPresetIndex},
                    onSelectionChanged: (s) =>
                        viewModel.setVideoPresetIndex(s.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Slower encoding makes a smaller file for the same quality.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),

              // Desktop only: results go into a folder there.
              if (PlatformInfo.isDesktop)
                const _Section(
                  title: 'Saving',
                  icon: Icons.folder_outlined,
                  children: [SaveToTile()],
                ),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: viewModel.resetToDefaults,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset to defaults'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.divisions,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String valueLabel;
  final double value;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
            Text(valueLabel,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
        Slider(
          value: value.clamp(0.0, 1.0),
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
        if (hint != null) Text(hint!, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
