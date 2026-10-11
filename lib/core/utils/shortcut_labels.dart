import 'package:petit/core/utils/platform_utils.dart';

/// The modifier key people on this platform expect for app shortcuts.
String get shortcutModifierLabel => PlatformInfo.isMacOS ? '⌘' : 'Ctrl';

/// Adds a shortcut hint to a tooltip on desktop, e.g. `Add images (Ctrl+O)`.
/// [key] is the key name, e.g. `O`, `Enter`, `Del`. When [withModifier] is
/// false the key is shown on its own (e.g. `Esc`).
String withShortcut(String tooltip, String key, {bool withModifier = true}) {
  if (!PlatformInfo.isDesktop) return tooltip;
  final combo = withModifier ? '$shortcutModifierLabel+$key' : key;
  return '$tooltip ($combo)';
}
