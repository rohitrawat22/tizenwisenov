import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';

/// The mode the [PinInputDialog] operates in.
enum PinDialogMode {
  /// Verify an existing PIN (single entry).
  verify,

  /// Set up a new PIN (enter → confirm).
  setup,

  /// Change PIN (enter old → enter new → confirm new).
  change,

  /// Remove PIN (enter current to confirm removal).
  remove,
}

class PinInputDialog extends StatefulWidget {
  final PinDialogMode mode;
  final String titleOverride;

  const PinInputDialog({
    super.key,
    this.mode = PinDialogMode.verify,
    this.titleOverride = '',
  });

  @override
  State<PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<PinInputDialog>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  final int _pinLength = 4;

  late _PinStep _currentStep;
  String? _firstEntry;
  String? _oldPin;
  String _errorText = '';

  late AnimationController _shakeController;

  // TV D-pad Focus Nodes:
  // Layout:
  //   [1] [2] [3]   → indices 1, 2, 3
  //   [4] [5] [6]   → indices 4, 5, 6
  //   [7] [8] [9]   → indices 7, 8, 9
  //   [C] [0] [⌫]   → indices 10, 0, 11
  final List<FocusNode> _keyNodes = List.generate(
    12,
    (i) => FocusNode(debugLabel: 'pin_key_$i'),
  );

  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'pin_close_button');

  @override
  void initState() {
    super.initState();
    _currentStep = _initialStep(widget.mode);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _wireKeypadDpad();

    // Focus key '1' on TV by default so D-Pad remote navigation works immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyNodes[1].requestFocus();
      }
    });
  }

  void _wireKeypadDpad() {
    final n = _keyNodes;

    // Close button node at top-right
    wireDpadNode(
      _closeFocusNode,
      lockUp: true,
      lockLeft: true,
      lockRight: true,
      down: n[3], // Down goes to button '3'
      onSelect: () => Navigator.of(context).pop(),
    );

    // Row 0: 1, 2, 3
    wireDpadNode(
      n[1],
      up: _closeFocusNode,
      lockLeft: true,
      right: n[2],
      down: n[4],
      onSelect: () => _onKeyPress('1'),
    );
    wireDpadNode(
      n[2],
      up: _closeFocusNode,
      left: n[1],
      right: n[3],
      down: n[5],
      onSelect: () => _onKeyPress('2'),
    );
    wireDpadNode(
      n[3],
      up: _closeFocusNode,
      left: n[2],
      lockRight: true,
      down: n[6],
      onSelect: () => _onKeyPress('3'),
    );

    // Row 1: 4, 5, 6
    wireDpadNode(
      n[4],
      up: n[1],
      lockLeft: true,
      right: n[5],
      down: n[7],
      onSelect: () => _onKeyPress('4'),
    );
    wireDpadNode(
      n[5],
      up: n[2],
      left: n[4],
      right: n[6],
      down: n[8],
      onSelect: () => _onKeyPress('5'),
    );
    wireDpadNode(
      n[6],
      up: n[3],
      left: n[5],
      lockRight: true,
      down: n[9],
      onSelect: () => _onKeyPress('6'),
    );

    // Row 2: 7, 8, 9
    wireDpadNode(
      n[7],
      up: n[4],
      lockLeft: true,
      right: n[8],
      down: n[10],
      onSelect: () => _onKeyPress('7'),
    );
    wireDpadNode(
      n[8],
      up: n[5],
      left: n[7],
      right: n[9],
      down: n[0],
      onSelect: () => _onKeyPress('8'),
    );
    wireDpadNode(
      n[9],
      up: n[6],
      left: n[8],
      lockRight: true,
      down: n[11],
      onSelect: () => _onKeyPress('9'),
    );

    // Row 3: C (clear), 0, ⌫ (backspace)
    wireDpadNode(
      n[10],
      up: n[7],
      lockLeft: true,
      right: n[0],
      lockDown: true,
      onSelect: _onClear,
    );
    wireDpadNode(
      n[0],
      up: n[8],
      left: n[10],
      right: n[11],
      lockDown: true,
      onSelect: () => _onKeyPress('0'),
    );
    wireDpadNode(
      n[11],
      up: n[9],
      left: n[0],
      lockRight: true,
      lockDown: true,
      onSelect: _onBackspace,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    for (var node in _keyNodes) {
      node.dispose();
    }
    _closeFocusNode.dispose();
    super.dispose();
  }

  _PinStep _initialStep(PinDialogMode mode) {
    switch (mode) {
      case PinDialogMode.verify:
        return _PinStep.enterPin;
      case PinDialogMode.setup:
        return _PinStep.enterNewPin;
      case PinDialogMode.change:
        return _PinStep.enterOldPin;
      case PinDialogMode.remove:
        return _PinStep.enterPinToRemove;
    }
  }

  String get _title {
    if (widget.titleOverride.isNotEmpty) return widget.titleOverride;
    switch (_currentStep) {
      case _PinStep.enterPin:
        return "Security PIN";
      case _PinStep.enterNewPin:
        return "Create New PIN";
      case _PinStep.confirmNewPin:
        return "Confirm New PIN";
      case _PinStep.enterOldPin:
        return "Enter Current PIN";
      case _PinStep.enterPinToRemove:
        return "Remove PIN";
    }
  }

  String get _subtitle {
    switch (_currentStep) {
      case _PinStep.enterPin:
        return "Enter 4-digit PIN to continue";
      case _PinStep.enterNewPin:
        return "Enter a 4-digit PIN";
      case _PinStep.confirmNewPin:
        return "Re-enter PIN to confirm";
      case _PinStep.enterOldPin:
        return "Enter current PIN first";
      case _PinStep.enterPinToRemove:
        return "Enter current PIN to remove";
    }
  }

  void _onKeyPress(String key) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += key;
        _errorText = '';
      });
      if (_pin.length == _pinLength) {
        _submitPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorText = '';
      });
    }
  }

  void _onClear() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = '';
        _errorText = '';
      });
    }
  }

  /// Handles raw key events at the dialog-root Focus node.
  /// Covers hardware keyboard digit presses (phones/emulator keyboard),
  /// backspace, and the Back/Escape button to dismiss.
  ///
  /// TV remote D-pad navigation is handled by [wireDpadNode] on each key node.
  KeyEventResult _handleRootKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    // ── Digit keys (hardware keyboard) ──────────────────────────────────────
    final Map<LogicalKeyboardKey, String> digitMap = {
      LogicalKeyboardKey.digit0: '0',
      LogicalKeyboardKey.numpad0: '0',
      LogicalKeyboardKey.digit1: '1',
      LogicalKeyboardKey.numpad1: '1',
      LogicalKeyboardKey.digit2: '2',
      LogicalKeyboardKey.numpad2: '2',
      LogicalKeyboardKey.digit3: '3',
      LogicalKeyboardKey.numpad3: '3',
      LogicalKeyboardKey.digit4: '4',
      LogicalKeyboardKey.numpad4: '4',
      LogicalKeyboardKey.digit5: '5',
      LogicalKeyboardKey.numpad5: '5',
      LogicalKeyboardKey.digit6: '6',
      LogicalKeyboardKey.numpad6: '6',
      LogicalKeyboardKey.digit7: '7',
      LogicalKeyboardKey.numpad7: '7',
      LogicalKeyboardKey.digit8: '8',
      LogicalKeyboardKey.numpad8: '8',
      LogicalKeyboardKey.digit9: '9',
      LogicalKeyboardKey.numpad9: '9',
    };

    if (digitMap.containsKey(key)) {
      _onKeyPress(digitMap[key]!);
      return KeyEventResult.handled;
    }

    // ── Backspace / Delete ───────────────────────────────────────────────────
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _onBackspace();
      return KeyEventResult.handled;
    }

    // ── Escape / Back button — dismiss dialog ────────────────────────────────
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _submitPin() {
    switch (_currentStep) {
      case _PinStep.enterPin:
      case _PinStep.enterPinToRemove:
        Navigator.of(context).pop(_pin);
        break;
      case _PinStep.enterNewPin:
        _firstEntry = _pin;
        setState(() {
          _pin = '';
          _currentStep = _PinStep.confirmNewPin;
        });
        // Refocus key '1' after step change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _keyNodes[1].requestFocus();
        });
        break;
      case _PinStep.confirmNewPin:
        if (_pin == _firstEntry) {
          if (widget.mode == PinDialogMode.change) {
            Navigator.of(context).pop({'oldPin': _oldPin, 'newPin': _pin});
          } else {
            Navigator.of(context).pop(_pin);
          }
        } else {
          _shakeController.forward(from: 0);
          setState(() {
            _pin = '';
            _errorText = "PINs don't match";
            _currentStep = _PinStep.enterNewPin;
            _firstEntry = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _keyNodes[1].requestFocus();
          });
        }
        break;
      case _PinStep.enterOldPin:
        _oldPin = _pin;
        setState(() {
          _pin = '';
          _currentStep = _PinStep.enterNewPin;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _keyNodes[1].requestFocus();
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Root Focus node handles hardware-keyboard digit presses and Back/Escape.
    // TV D-pad arrows are handled individually by wireDpadNode on each key button.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Focus(
        onKeyEvent: _handleRootKeyEvent,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          child: Container(
            width: 330,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF141820),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColor.accentRed.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColor.accentRed.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Lock icon centred
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColor.accentRed.withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: AppColor.accentRed,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _title,
                        style: const TextStyle(
                          color: AppColor.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColor.white.withValues(alpha: 0.65),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Error Text or spacing
                      SizedBox(
                        height: 18,
                        child: _errorText.isNotEmpty
                            ? Text(
                                _errorText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColor.accentRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),

                      // PIN Dots
                      _buildPinDots(),
                      const SizedBox(height: 20),

                      // Keypad
                      _buildKeypad(),
                    ],
                  ),
                ),
                // Close button pinned at top-right corner without overlapping header icon
                Positioned(
                  right: 12,
                  top: 12,
                  child: _CloseButton(
                    focusNode: _closeFocusNode,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (index) {
        final isFilled = index < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 7),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? AppColor.accentRed
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: isFilled
                  ? AppColor.accentRed
                  : Colors.white.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: AppColor.accentRed.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    // FocusTraversalGroup with ReadingOrderTraversalPolicy ensures Tab-key
    // cycles in reading order as a fallback on physical keyboards.
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKey('1', _keyNodes[1]),
              const SizedBox(width: 12),
              _buildKey('2', _keyNodes[2]),
              const SizedBox(width: 12),
              _buildKey('3', _keyNodes[3]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKey('4', _keyNodes[4]),
              const SizedBox(width: 12),
              _buildKey('5', _keyNodes[5]),
              const SizedBox(width: 12),
              _buildKey('6', _keyNodes[6]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKey('7', _keyNodes[7]),
              const SizedBox(width: 12),
              _buildKey('8', _keyNodes[8]),
              const SizedBox(width: 12),
              _buildKey('9', _keyNodes[9]),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionKey(
                icon: Icons.refresh_rounded,
                label: 'C',
                focusNode: _keyNodes[10],
                onTap: _onClear,
                tooltip: 'Clear',
              ),
              const SizedBox(width: 12),
              _buildKey('0', _keyNodes[0]),
              const SizedBox(width: 12),
              _buildActionKey(
                icon: Icons.backspace_outlined,
                focusNode: _keyNodes[11],
                onTap: _onBackspace,
                tooltip: 'Backspace',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String value, FocusNode focusNode) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: InkWell(
            focusNode: focusNode,
            onTap: () => _onKeyPress(value),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isFocused
                    ? AppColor.accentRed
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: isFocused
                      ? AppColor.white
                      : Colors.white.withValues(alpha: 0.1),
                  width: isFocused ? 2 : 1,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: AppColor.accentRed.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: Text(
                value,
                style: TextStyle(
                  color: isFocused
                      ? AppColor.white
                      : AppColor.white.withValues(alpha: 0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionKey({
    IconData? icon,
    String? label,
    required FocusNode focusNode,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: InkWell(
            focusNode: focusNode,
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isFocused
                    ? AppColor.accentRed.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                  color: isFocused
                      ? AppColor.white
                      : Colors.white.withValues(alpha: 0.08),
                  width: isFocused ? 2 : 1,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: AppColor.accentRed.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: icon != null
                  ? Icon(
                      icon,
                      color: isFocused
                          ? AppColor.white
                          : AppColor.white.withValues(alpha: 0.7),
                      size: 20,
                    )
                  : Text(
                      label ?? '',
                      style: TextStyle(
                        color: isFocused
                            ? AppColor.white
                            : AppColor.white.withValues(alpha: 0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

enum _PinStep {
  enterPin,
  enterNewPin,
  confirmNewPin,
  enterOldPin,
  enterPinToRemove,
}

/// Small animated ✕ icon button used to dismiss PIN dialogs.
/// Works for both touch (phone) and D-pad focus (TV).
class _CloseButton extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _CloseButton({required this.focusNode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: InkWell(
            focusNode: focusNode,
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFocused
                    ? AppColor.accentRed.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: isFocused
                      ? AppColor.accentRed
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: isFocused
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      },
    );
  }
}
