// get_dymention.dart
//
// ⚠️  DEPRECATED — do not add new usages.
//
// These globals were set once in ScreenLayoutScreen's LayoutBuilder and read
// from ~11 other files.  They are UNSAFE because they go stale after device
// rotation, split-screen, or multi-window resizing, causing misaligned /
// overlapping layouts.
//
// Migration path (all files already migrated as of 2026-08):
//   • Replace `mWidth`  → `MediaQuery.sizeOf(context).width`
//   • Replace `mHeight` → `MediaQuery.sizeOf(context).height`
//   • Replace `isPhone` → `isPhoneWidth(context)` from breakpoints.dart,
//                          or a `late final bool _isPhone` field captured in
//                          initState() for use in dispose().
//   • Replace `isweb`   → `deviceTypeOf(context) != DeviceType.mobile`
//
// After all consumers are migrated, this file will be deleted.

import 'package:flutter/material.dart';

@Deprecated('Use MediaQuery.sizeOf(context).width instead. See breakpoints.dart.')
double mHeight = 0;

@Deprecated('Use MediaQuery.sizeOf(context).height instead. See breakpoints.dart.')
double mWidth = 0;

@Deprecated('Use isPhoneWidth(context) from breakpoints.dart instead.')
bool isPhone = false;

@Deprecated('Use deviceTypeOf(context) != DeviceType.mobile from breakpoints.dart instead.')
bool isweb = false;

/// Sets [mWidth] and [mHeight] from the given context.
///
/// @Deprecated — call sites should switch to MediaQuery.sizeOf(context) directly.
@Deprecated('Do not call. Use MediaQuery.sizeOf(context) directly inside build().')
// ignore: non_constant_identifier_names
getDymentation(BuildContext context) {
  mHeight = MediaQuery.sizeOf(context).height;
  mWidth = MediaQuery.sizeOf(context).width;
  return;
}
