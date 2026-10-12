// breakpoints.dart
//
// Single source of truth for layout breakpoints.
// All screens should use [deviceTypeOf] (or a local MediaQuery read) instead
// of the legacy mWidth / mHeight / isPhone / isweb globals from get_dymention.dart.

import 'package:flutter/widgets.dart';

/// Pixel-width thresholds (logical pixels, not physical).
abstract final class Breakpoints {
  /// < 600 → phone / small device.
  static const double mobile = 600;

  /// 600 – 1239 → tablet / small laptop / TV side-panel.
  static const double tablet = 905;

  /// ≥ 1240 → desktop / large-screen TV.
  static const double desktop = 1240;
}

/// Coarse device category inferred from the current screen width.
enum DeviceType { mobile, tablet, desktop }

/// Returns the [DeviceType] for the nearest [MediaQuery] ancestor.
///
/// Must be called inside a widget `build()` method (or `initState` after the
/// first frame via `WidgetsBinding.instance.addPostFrameCallback`) so that
/// [MediaQuery.sizeOf] has a valid context.
DeviceType deviceTypeOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < Breakpoints.mobile) return DeviceType.mobile;
  if (w < Breakpoints.desktop) return DeviceType.tablet;
  return DeviceType.desktop;
}

/// Convenience: returns `true` when the device is narrower than [Breakpoints.mobile].
bool isPhoneWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < Breakpoints.mobile;
