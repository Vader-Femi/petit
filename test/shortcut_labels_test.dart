import 'package:flutter_test/flutter_test.dart';
import 'package:petit/core/utils/platform_utils.dart';
import 'package:petit/core/utils/shortcut_labels.dart';

void main() {
  test('shortcut hints only appear on desktop', () {
    final modifier = PlatformInfo.isMacOS ? '\u2318' : 'Ctrl';

    if (PlatformInfo.isDesktop) {
      expect(withShortcut('Add images', 'O'), 'Add images ($modifier+O)');
      expect(withShortcut('Cancel', 'Esc', withModifier: false), 'Cancel (Esc)');
    } else {
      expect(withShortcut('Add images', 'O'), 'Add images');
    }
  });
}
