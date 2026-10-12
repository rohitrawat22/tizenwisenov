import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../colors/colors.dart';

/// A TV-safe search bar.
///
/// On Android TV / Fire TV the keyboard must NOT open automatically when the
/// field receives D-pad focus — it should only open when the user presses
/// Enter / OK on the remote.  This widget achieves that by:
///   1. Making the [TextFormField] read-only by default.
///   2. On Enter key → switching to "active" mode (keyboard opens).
///   3. On Escape / Back → dismissing the keyboard and going back to passive.
///
/// The [onChanged] callback is fired on every text change when active.
class CustomTextFormFiled extends StatefulWidget {
  final FocusNode? focusNode;
  final bool isReadOnly;
  final TextEditingController controller;
  final String hintText;
  final double borderRadius;
  final Color borderSideColor;
  final Color fixedBorderSideColor;
  final bool isFilled;
  final bool obscureText;
  final Color filledColor;
  final int maxLines;
  final int? maxWords;
  final TextInputType keyboardType;
  final bool isEnabled;
  final bool isDigitsOnly;
  final bool isPreFixText;
  final String? prefixText;
  final bool isBorder;
  final Color fillColor;
  final bool isPreFixIcon;
  final Widget prefixIcon;
  final Widget suffixIcon;
  final bool autoFoucs;
  final Function(String?)? onSave;
  final bool isOnChanged;
  final Function(String)? onChanged;

  const CustomTextFormFiled({
    super.key,
    required this.controller,
    this.hintText = '',
    this.prefixIcon = const SizedBox(),
    this.isReadOnly = false,
    this.borderRadius = 12,
    this.borderSideColor = Colors.white24,
    this.isFilled = true,
    this.obscureText = false,
    this.filledColor = const Color(0xFF1E293B),
    this.fixedBorderSideColor = AppColor.accentCyan,
    this.maxLines = 1,
    this.maxWords,
    this.keyboardType = TextInputType.name,
    this.isEnabled = true,
    this.isDigitsOnly = false,
    this.isPreFixText = false,
    this.prefixText,
    this.isBorder = true,
    this.fillColor = const Color(0x0AFFFFFF),
    this.isPreFixIcon = false,
    this.focusNode,
    this.suffixIcon = const SizedBox(),
    this.autoFoucs = false,
    this.onSave,
    this.isOnChanged = false,
    this.onChanged,
  });

  @override
  State<CustomTextFormFiled> createState() => _CustomTextFormFiledState();
}

class _CustomTextFormFiledState extends State<CustomTextFormFiled> {
  /// The D-pad outer focus node — this receives D-pad focus from navigation.
  late final FocusNode _dpadNode;

  /// The actual text field focus node — only activated on Enter.
  late final FocusNode _fieldNode;

  /// Whether the keyboard is open (field is actively editing).
  bool _isActive = false;

  bool get _isTV => MediaQuery.of(context).size.width > 800;

  @override
  void initState() {
    super.initState();
    _dpadNode = widget.focusNode ?? FocusNode(debugLabel: 'search_dpad');
    _fieldNode = FocusNode(debugLabel: 'search_field');

    _dpadNode.addListener(_onDpadFocusChange);
    _fieldNode.addListener(_onFieldFocusChange);
  }

  void _onDpadFocusChange() {
    if (mounted) setState(() {});
    // When the D-pad node loses focus entirely, deactivate typing.
    if (!_dpadNode.hasFocus && !_fieldNode.hasFocus) {
      _deactivate();
    }
  }

  void _onFieldFocusChange() {
    if (mounted) setState(() {});
    if (!_fieldNode.hasFocus && _isActive) {
      _deactivate();
    }
  }

  void _activate() {
    if (!_isActive && mounted) {
      setState(() => _isActive = true);
      // Small delay so the widget rebuilds in read-write mode first,
      // then request field focus to open keyboard.
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _fieldNode.requestFocus();
      });
    }
  }

  void _deactivate() {
    if (_isActive && mounted) {
      setState(() => _isActive = false);
      if (_fieldNode.hasFocus) {
        _fieldNode.unfocus();
        FocusScope.of(context).requestFocus(_dpadNode);
      }
    }
  }

  void _clearAndDeactivate() {
    widget.controller.clear();
    if (widget.isOnChanged) widget.onChanged?.call('');
    _deactivate();
  }

  @override
  void dispose() {
    _dpadNode.removeListener(_onDpadFocusChange);
    _fieldNode.removeListener(_onFieldFocusChange);
    // Only dispose the field node — the D-pad node is owned by the parent
    // if the caller passed one in; otherwise we own it.
    _fieldNode.dispose();
    if (widget.focusNode == null) _dpadNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDpadFocused = _dpadNode.hasFocus;
    final isFocused = isDpadFocused || _isActive;

    return Focus(
      focusNode: _dpadNode,
      // Intercept D-pad keys on the outer focus node.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          // Enter / Select / OK → activate typing
          if (!_isActive &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            _activate();
            return KeyEventResult.handled;
          }
          // Escape / Back → deactivate
          if (_isActive &&
              (event.logicalKey == LogicalKeyboardKey.escape ||
                  event.logicalKey == LogicalKeyboardKey.browserBack ||
                  event.logicalKey == LogicalKeyboardKey.goBack)) {
            _deactivate();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: _isActive
              ? const Color(0xFF1E293B)
              : (isFocused ? const Color(0xFF1A1A2E) : widget.fillColor),
          border: Border.all(
            color: _isActive
                ? widget.fixedBorderSideColor
                : (isFocused
                      ? widget.fixedBorderSideColor.withValues(alpha: 0.7)
                      : widget.borderSideColor),
            width: _isActive ? 2.0 : (isFocused ? 2.0 : 1.5),
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: widget.fixedBorderSideColor.withValues(
                      alpha: _isActive ? 0.25 : 0.12,
                    ),
                    blurRadius: _isActive ? 14 : 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // ── Search Icon ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isActive
                      ? Icons.keyboard_alt_outlined
                      : Icons.search_rounded,
                  key: ValueKey(_isActive),
                  color: _isActive
                      ? widget.fixedBorderSideColor
                      : (isFocused
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.4)),
                  size: 20,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ── Text Field / Passive Label ───────────────────────────────
            Expanded(
              child: _isActive
                  ? TextFormField(
                      focusNode: _fieldNode,
                      autofocus: false,
                      controller: widget.controller,
                      keyboardType: widget.keyboardType,
                      obscureText: widget.obscureText,
                      maxLines: widget.maxLines,
                      maxLength: widget.maxWords,
                      inputFormatters: widget.isDigitsOnly
                          ? [FilteringTextInputFormatter.digitsOnly]
                          : null,
                      onSaved: widget.onSave,
                      onChanged: widget.isOnChanged ? widget.onChanged : null,
                      onEditingComplete: _deactivate,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 15,
                        ),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _activate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          widget.controller.text.isNotEmpty
                              ? widget.controller.text
                              : widget.hintText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.controller.text.isNotEmpty
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.35),
                            fontSize: 15,
                            fontWeight: widget.controller.text.isNotEmpty
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
            ),

            // ── Trailing: hints or clear ────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isActive
                  ? (widget.controller.text.isNotEmpty
                        ? IconButton(
                            key: const ValueKey('clear'),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                            onPressed: _clearAndDeactivate,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          )
                        : const SizedBox(key: ValueKey('empty'), width: 12))
                  : const SizedBox(key: ValueKey('none'), width: 12),
            ),
          ],
        ),
      ),
    );
  }
}
