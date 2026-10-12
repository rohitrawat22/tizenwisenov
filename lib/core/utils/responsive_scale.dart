// responsive_scale.dart
//
// Extension on BuildContext for responsive sizing helpers.
// Use [scaleW] when you have a design reference value (based on a 375-wide
// baseline phone screen) that should scale proportionally on other widths,
// but should never go absurdly small or large.

import 'package:flutter/widgets.dart';

extension ResponsiveScale on BuildContext {
  /// Current logical screen width from the nearest MediaQuery ancestor.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Current logical screen height from the nearest MediaQuery ancestor.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Scale [designPx] (a pixel value measured on a 375-wide reference screen)
  /// proportionally to the current screen width.
  ///
  /// [min] and [max] clamp the scale factor so the result never shrinks below
  /// `designPx * min` or grows beyond `designPx * max`.
  ///
  /// Example: `context.scaleW(120)` on a 390-wide phone → ~124px.
  ///          `context.scaleW(120)` on a 1920-wide TV    → 192px (capped by max 1.6).
  double scaleW(double designPx, {double min = 0.8, double max = 1.6}) {
    final factor = (screenWidth / 375).clamp(min, max);
    return designPx * factor;
  }
}
