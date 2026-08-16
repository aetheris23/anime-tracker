import 'package:flutter/widgets.dart';

/// Utility for adaptive, safe-area-aware responsive layout.
///
/// Handles the wide variety of phone screens: notches, punch-holes,
/// waterdrop cutouts, under-display cameras, thick bezels and gesture bars.
/// All insets come from [MediaQuery], which the OS populates from the actual
/// device display features.
class Screen {
  /// Whether the available width is enough for a tablet-like layout.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 760;

  /// Whether the device is tablet-sized (including large phones in landscape).
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  /// Horizontal gutter that scales with the screen width.
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1400) return 36;
    if (width >= 1000) return 28;
    if (width >= 760) return 24;
    if (width >= 400) return 16;
    return 12;
  }

  /// Vertical gutter that scales with the screen width.
  static double verticalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 760) return 20;
    return 12;
  }

  /// The system safe inset at the top (status bar / notch / punch-hole).
  static double topInset(BuildContext context) {
    final mq = MediaQuery.of(context);
    return topInsetFor(mq);
  }

  static double topInsetFor(MediaQueryData mq) {
    // viewPadding always reports the physical system inset, even when the
    // window is edge-to-edge; padding is the currently obscured amount.
    var top = mq.viewPadding.top > mq.padding.top
        ? mq.viewPadding.top
        : mq.padding.top;
    // Some devices (under-display cameras, small cutouts) only report
    // display features; include a minimal fallback.
    for (final feature in mq.displayFeatures) {
      final bound = feature.bounds;
      if (bound.top < top) top = bound.top;
    }
    return top;
  }

  /// The system safe inset at the bottom (gesture bar / navigation bar).
  static double bottomInset(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.viewPadding.bottom > mq.padding.bottom
        ? mq.viewPadding.bottom
        : mq.padding.bottom;
  }

  /// Wraps [child] in a safe area that respects every cutout/inset the device
  /// reports. [top]/[bottom] toggle whether that edge is padded.
  static Widget safe(
    BuildContext context,
    Widget child, {
    bool top = true,
    bool bottom = true,
    double minimum = 0,
  }) {
    return SafeArea(
      top: top,
      bottom: bottom,
      minimum: EdgeInsets.all(minimum),
      child: child,
    );
  }
}
