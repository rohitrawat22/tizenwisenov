import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Detects whether the current device is an Android TV / Google TV.
///
/// Primary check  : native platform channel querying UI_MODE_TYPE_TELEVISION.
/// Fallback check : screen-width heuristic (>= 960 dp) used only when the
///                  channel call fails (e.g. on non-Android platforms).
class TvDetector {
  TvDetector._();

  static const MethodChannel _channel =
      MethodChannel('wise_players/tv_detector');

  /// Cached result — detection only needs to run once per app session.
  static bool? _cachedIsTV;

  /// Returns [true] if the device is an Android TV / Google TV.
  ///
  /// Caches the first result so subsequent awaits are O(1).
  static Future<bool> isTV({double screenWidthDp = 0}) async {
    if (_cachedIsTV != null) return _cachedIsTV!;

    if (Platform.isAndroid) {
      try {
        final bool result =
            await _channel.invokeMethod<bool>('isTelevision') ?? false;
        _cachedIsTV = result;
        return result;
      } on PlatformException catch (e) {
        debugPrint('[TvDetector] PlatformException: ${e.message}');
        // Fall through to heuristic
      } on MissingPluginException {
        debugPrint('[TvDetector] Channel not registered yet — using heuristic');
        // Fall through to heuristic
      }
    }

    // Fallback: landscape screen wider than 960 dp is almost certainly a TV
    // or large tablet that should use the TV layout.
    final bool heuristic = screenWidthDp >= 960;
    _cachedIsTV = heuristic;
    return heuristic;
  }

  /// Reset the cache (useful for testing).
  @visibleForTesting
  static void resetCache() => _cachedIsTV = null;
}
