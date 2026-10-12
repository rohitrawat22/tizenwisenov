import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';

import '../localization/generated/l10n.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Premium Exit / Logout dialog — optimized for smooth animation on TV & mobile
// BackdropFilter removed (it was the primary source of jank on low-end GPUs).
// ─────────────────────────────────────────────────────────────────────────────

showExitDialog(BuildContext context, S s) async {
  return await showDialog<bool>(
        barrierDismissible: false,
        barrierColor: Colors.black54,
        context: context,
        builder: (context) => _ExitDialog(s: s),
      ) ??
      false;
}

class _ExitDialog extends StatefulWidget {
  final S s;
  const _ExitDialog({required this.s});

  @override
  State<_ExitDialog> createState() => _ExitDialogState();
}

class _ExitDialogState extends State<_ExitDialog>
    with SingleTickerProviderStateMixin {
  final FocusNode _cancelNode = FocusNode(debugLabel: 'exit_cancel');
  final FocusNode _exitNode = FocusNode(debugLabel: 'exit_confirm');

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Faster, lighter animation — no spring curve (easeOutBack is expensive).
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(
      begin: 0.90,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    // D-pad: right on Cancel → Exit
    _cancelNode.onKeyEvent = (node, event) {
      if (event is! KeyUpEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _exitNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // D-pad: left on Exit → Cancel
    _exitNode.onKeyEvent = (node, event) {
      if (event is! KeyUpEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _cancelNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // Auto-focus Cancel so user can press back to dismiss
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cancelNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelNode.dispose();
    _exitNode.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _cancel() => Navigator.of(context).pop(false);
  void _confirmExit() => SystemNavigator.pop();

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final bool isSmallScreen = screenHeight < 500;
    final double hPad = screenWidth < 500
        ? 20.0
        : (screenWidth < 900 ? 24.0 : 40.0);
    final double vPad = isSmallScreen ? 8.0 : 60.0;

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          // No ClipRRect + BackdropFilter — replaced with solid dark surface.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: screenHeight * 0.95,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A0808),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColor.accentRed.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  28,
                  isSmallScreen ? 20 : 32,
                  28,
                  isSmallScreen ? 20 : 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Icon ──────────────────────────────────────────────
                    if (!isSmallScreen)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColor.accentRed.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColor.accentRed.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.power_settings_new_rounded,
                          color: AppColor.accentRed,
                          size: 36,
                        ),
                      ),

                    if (!isSmallScreen) const SizedBox(height: 20),

                    // ── Title ─────────────────────────────────────────────
                    Text(
                      widget.s.exit,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: isSmallScreen ? 8 : 12),

                    // ── Message ───────────────────────────────────────────
                    Text(
                      widget.s.exitConfirmMessage,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: isSmallScreen ? 14 : 16,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 36),

                    // ── Actions ───────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _ExitDialogButton(
                            focusNode: _cancelNode,
                            label: widget.s.cancel,
                            onTap: _cancel,
                            isPrimary: false,
                            isSmallScreen: isSmallScreen,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ExitDialogButton(
                            focusNode: _exitNode,
                            label: widget.s.exit,
                            onTap: _confirmExit,
                            isPrimary: true,
                            isSmallScreen: isSmallScreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated button — fast, lightweight focus highlight
// ─────────────────────────────────────────────────────────────────────────────
class _ExitDialogButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isSmallScreen;

  const _ExitDialogButton({
    required this.focusNode,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    this.isSmallScreen = false,
  });

  @override
  State<_ExitDialogButton> createState() => _ExitDialogButtonState();
}

class _ExitDialogButtonState extends State<_ExitDialogButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    // Decoration computed once per build — no extra AnimatedContainer layer.
    final decoration = BoxDecoration(
      color: widget.isPrimary
          ? (_isFocused
                ? AppColor.accentRed
                : AppColor.accentRed.withValues(alpha: 0.75))
          : (_isFocused
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.08)),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: widget.isPrimary
            ? (_isFocused
                  ? Colors.white
                  : AppColor.accentRed.withValues(alpha: 0.6))
            : (_isFocused
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15)),
        width: _isFocused ? 2 : 1,
      ),
    );

    return InkWell(
      focusNode: widget.focusNode,
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: widget.isSmallScreen ? 12 : 16),
        decoration: decoration,
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isPrimary
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.9),
              fontSize: widget.isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
