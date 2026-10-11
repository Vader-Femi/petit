import 'package:flutter_test/flutter_test.dart';
import 'package:petit/core/utils/adaptive.dart';

void main() {
  test('window size classes follow the Material 3 breakpoints', () {
    expect(windowSizeFor(360), WindowSize.compact);
    expect(windowSizeFor(599.9), WindowSize.compact);
    expect(windowSizeFor(600), WindowSize.medium);
    expect(windowSizeFor(839.9), WindowSize.medium);
    expect(windowSizeFor(840), WindowSize.expanded);
    expect(windowSizeFor(1920), WindowSize.expanded);
  });

  test('the rail appears before the two-pane layout', () {
    expect(kRailMinWidth, lessThan(kTwoPaneMinWidth));
    // A two-pane page must leave room for the preview next to the controls.
    expect(kTwoPaneMinWidth, greaterThan(kControlsPaneWidth * 1.5));
  });
}
