import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:petit/common/state/output_folder_viewmodel.dart';
import 'package:petit/core/utils/platform_utils.dart';

/// "Save to: Pictures/Petit  [Change]" on desktop, where results go into a
/// folder. Shows nothing on mobile, where results go to the gallery.
class SaveToTile extends ConsumerWidget {
  const SaveToTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!PlatformInfo.isDesktop) return const SizedBox.shrink();

    final folder = ref.watch(outputFolderViewModelProvider);
    final viewModel = ref.read(outputFolderViewModelProvider.notifier);
    final theme = Theme.of(context);

    return folder.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (path) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: path ?? 'A folder dialog opens before each job',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Save to', style: theme.textTheme.labelSmall),
                      Text(
                        path == null ? 'Ask each time' : p.basename(path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: viewModel.choose,
                child: const Text('Change'),
              ),
              if (path != null)
                IconButton(
                  tooltip: 'Ask each time',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: viewModel.askEachTime,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
