import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';

/// A catch-up (timeshift) selection returned by [showCatchUpPickerDialog].
class CatchUpSelection {
  final DateTime start;
  final int durationMinutes;

  const CatchUpSelection({required this.start, required this.durationMinutes});

  /// ISO-8601 string the backend timeshift endpoint accepts,
  /// e.g. `2026-08-14T14:30:00`.
  String get timestamp => DateFormat('yyyy-MM-ddTHH:mm:ss').format(start);
}

/// Shows the catch-up picker and returns the chosen [CatchUpSelection],
/// or `null` when the user cancels.
Future<CatchUpSelection?> showCatchUpPickerDialog(
  BuildContext context, {
  required String channelName,
  required int archiveDays,
}) {
  return showDialog<CatchUpSelection>(
    context: context,
    barrierColor: Colors.black54,
    barrierDismissible: false,
    builder: (_) =>
        CatchUpPickerDialog(channelName: channelName, archiveDays: archiveDays),
  );
}

class CatchUpPickerDialog extends StatefulWidget {
  final String channelName;
  final int archiveDays;

  const CatchUpPickerDialog({
    super.key,
    required this.channelName,
    required this.archiveDays,
  });

  @override
  State<CatchUpPickerDialog> createState() => _CatchUpPickerDialogState();
}

class _CatchUpPickerDialogState extends State<CatchUpPickerDialog> {
  late final List<int> _offsets;
  late final List<FocusNode> _nodes;
  late final FocusNode _cancelNode;
  late final DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _cancelNode = FocusNode(debugLabel: 'catchup_cancel');

    const baseOffsets = [30, 60, 120, 180, 360, 720, 1440];
    final maxMinutes =
        (widget.archiveDays > 0 ? widget.archiveDays : 7) * 24 * 60;
    _offsets = baseOffsets
        .where((o) => o <= maxMinutes)
        .toList(growable: false);

    _nodes = List.generate(_offsets.length, (i) {
      final node = FocusNode(debugLabel: 'catchup_$i');
      node.onKeyEvent = (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final index = _nodes.indexOf(node);
        if (index == -1) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _moveFocus(index - 1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _moveFocus(index + 1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
      return node;
    });

    _cancelNode.onKeyEvent = (node, event) {
      if (event is! KeyUpEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (_nodes.isNotEmpty) {
            _nodes.last.requestFocus();
          }
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _nodes.isNotEmpty) {
        _nodes.first.requestFocus();
      }
    });
  }

  void _moveFocus(int index) {
    if (index >= 0 && index < _nodes.length) {
      _nodes[index].requestFocus();
    }
  }

  void _pick(int index) {
    final minutes = _offsets[index];
    final start = _now.subtract(Duration(minutes: minutes));
    Navigator.of(context)
        .pop(CatchUpSelection(start: start, durationMinutes: minutes));
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    _cancelNode.dispose();
    super.dispose();
  }

  String _offsetLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    if (minutes % 60 == 0 && minutes <= 720) {
      final hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    return '$minutes min';
  }

  String _timeLabel(int minutes) {
    final start = _now.subtract(Duration(minutes: minutes));
    return DateFormat('EEE, h:mm a').format(start);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 500;
    final hPad = MediaQuery.of(context).size.width < 500 ? 16.0 : 40.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: hPad, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
              24,
              isSmallScreen ? 16 : 28,
              24,
              isSmallScreen ? 16 : 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColor.accentRed.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColor.accentRed.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: AppColor.accentRed,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catch-up TV',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 17 : 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            widget.channelName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isSmallScreen ? 14 : 22),

                Text(
                  'Rewind to watch a past broadcast. Pick how far back to start:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: isSmallScreen ? 12 : 13,
                  ),
                ),

                SizedBox(height: isSmallScreen ? 12 : 16),

                for (var i = 0; i < _offsets.length; i++) ...[
                  _OptionTile(
                    focusNode: _nodes[i],
                    label: 'Watch from ${_offsetLabel(_offsets[i])} ago',
                    timeLabel: _timeLabel(_offsets[i]),
                    isSmallScreen: isSmallScreen,
                    onTap: () => _pick(i),
                  ),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 4),

                _OptionTile(
                  focusNode: _cancelNode,
                  label: 'Cancel',
                  timeLabel: null,
                  isSmallScreen: isSmallScreen,
                  onTap: _cancel,
                  isCancel: true,
                ),

                if (!isSmallScreen) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Use arrow keys to navigate',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final String? timeLabel;
  final bool isSmallScreen;
  final VoidCallback onTap;
  final bool isCancel;

  const _OptionTile({
    required this.focusNode,
    required this.label,
    required this.timeLabel,
    required this.isSmallScreen,
    required this.onTap,
    this.isCancel = false,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusNode: widget.focusNode,
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: widget.isSmallScreen ? 10 : 13,
        ),
        decoration: BoxDecoration(
          color: _focused
              ? (widget.isCancel
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppColor.accentRed)
              : (widget.isCancel
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColor.accentRed.withValues(alpha: 0.12)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused
                ? Colors.white
                : (widget.isCancel
                      ? Colors.white.withValues(alpha: 0.12)
                      : AppColor.accentRed.withValues(alpha: 0.4)),
            width: _focused ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.isCancel
                  ? Icons.close_rounded
                  : (widget.focusNode.hasFocus
                        ? Icons.play_circle_fill_rounded
                        : Icons.history_rounded),
              color: _focused
                  ? Colors.white
                  : (widget.isCancel ? Colors.white60 : AppColor.accentRed),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: _focused ? Colors.white : Colors.white70,
                  fontSize: widget.isSmallScreen ? 13 : 14,
                  fontWeight: _focused ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (widget.timeLabel != null)
              Text(
                widget.timeLabel!,
                style: TextStyle(
                  color: _focused ? Colors.white70 : Colors.white38,
                  fontSize: widget.isSmallScreen ? 11 : 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
