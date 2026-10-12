// ─────────────────────────────────────────────────────────────────────────────
// lib/core/utils/dpad_focus_graph.dart
//
// Shared D-pad / remote-control focus-graph helper for all TV screens.
//
// Usage:
//   wireDpadNode(
//     _myFocusNode,
//     up: _aboveFN,
//     down: _belowFN,
//     lockLeft: true,    // swallows the key without moving focus
//     onSelect: _doSomething,
//   );
//
// Rules:
//   • Call this in initState() (or whenever you rebuild the graph).
//   • target == null && locked == false → KeyEventResult.ignored (lets the
//     Flutter framework try its own tree-walk, avoids silent dead-ends).
//   • target == null && locked == true  → KeyEventResult.handled (swallows
//     the key; the remote appears to hit a wall, which is the correct UX at
//     screen edges).
//   • In debug mode a warning is printed when a direction is neither wired
//     nor explicitly locked, so dead-ends are caught during development.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Wires D-pad / remote-control key handling onto [node].
///
/// - [up], [down], [left], [right]: the FocusNode to move to when that
///   arrow key is pressed. Pass `null` plus the matching `lockXxx = true`
///   flag for edges where the remote should be blocked (screen boundary).
/// - [onSelect]: called when Enter / Select / OK / GameButtonA is pressed
///   while [node] has focus.
void wireDpadNode(
  FocusNode node, {
  FocusNode? up,
  FocusNode? down,
  FocusNode? left,
  FocusNode? right,
  bool lockUp = false,
  bool lockDown = false,
  bool lockLeft = false,
  bool lockRight = false,
  VoidCallback? onSelect,
}) {
  node.onKeyEvent = (_, event) {
    // Only act on KeyDown / KeyRepeat — ignore KeyUp to avoid double-firing.
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final k = event.logicalKey;

    // ── Select / OK / Enter ────────────────────────────────────────────────
    if (event is KeyDownEvent &&
        (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.gameButtonA)) {
      if (onSelect != null) {
        onSelect.call();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // ── Directional navigation ─────────────────────────────────────────────
    FocusNode? target;
    bool locked = false;

    if (k == LogicalKeyboardKey.arrowUp) {
      target = up;
      locked = lockUp;
    } else if (k == LogicalKeyboardKey.arrowDown) {
      target = down;
      locked = lockDown;
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      target = left;
      locked = lockLeft;
    } else if (k == LogicalKeyboardKey.arrowRight) {
      target = right;
      locked = lockRight;
    } else {
      return KeyEventResult.ignored;
    }

    if (target != null) {
      target.requestFocus();
      return KeyEventResult.handled;
    }

    if (locked) {
      // Intentional wall — swallow the key so it doesn't bubble elsewhere.
      return KeyEventResult.handled;
    }

    // ── Debug-only dead-end warning ────────────────────────────────────────
    // This fires during development whenever a direction has no target and
    // is not explicitly locked, which is almost always a missing wire-up.
    assert(() {
      debugPrint(
        '⚠️ D-pad dead-end: ${node.debugLabel ?? node.toString()} '
        'has no target for direction $k and is not locked.',
      );
      return true;
    }());

    // Not handled — let Flutter's default focus traversal try.
    return KeyEventResult.ignored;
  };
}

/// Dynamically attaches or wraps the [onSelect] action for a [FocusNode]
/// without losing any previously wired D-pad directional navigation.
void setNodeSelectCallback(FocusNode node, VoidCallback onSelect) {
  final parentHandler = node.onKeyEvent;
  node.onKeyEvent = (node, event) {
    final k = event.logicalKey;
    if (event is KeyDownEvent &&
        (k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.gameButtonA)) {
      onSelect();
      return KeyEventResult.handled;
    }
    if (parentHandler != null) {
      return parentHandler(node, event);
    }
    return KeyEventResult.ignored;
  };
}
