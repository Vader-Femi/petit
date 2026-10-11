/// Material 3 window size classes, used to decide the layout.
enum WindowSize { compact, medium, expanded }

/// Below this width the app uses a bottom navigation bar; from here up it
/// uses a navigation rail.
const double kRailMinWidth = 600;

/// From this width (of the content area) a page shows its preview and its
/// controls side by side instead of stacked.
const double kTwoPaneMinWidth = 720;

/// Width of the controls column in the two-pane layout.
const double kControlsPaneWidth = 360;

WindowSize windowSizeFor(double width) {
  if (width < 600) return WindowSize.compact;
  if (width < 840) return WindowSize.medium;
  return WindowSize.expanded;
}
