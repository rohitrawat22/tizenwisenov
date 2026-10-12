import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/location.dart';

class GeoLocationBanner extends StatefulWidget {
  const GeoLocationBanner({super.key});

  @override
  State<GeoLocationBanner> createState() => _GeoLocationBannerState();
}

class _GeoLocationBannerState extends State<GeoLocationBanner> {
  String address = "Fetching location...";
  bool _isPrecise = false;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Tick every minute to keep time accurate
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat("EEE, d MMM").format(_now);
    final time = DateFormat("HH:mm").format(_now);
    final bool isPhone = MediaQuery.of(context).size.width < 600;

    return Focus(
      canRequestFocus: true,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
          );
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select)) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;

          final decoration = BoxDecoration(
            gradient: isFocused
                ? const LinearGradient(
                    colors: [
                      Color(
                        0xFF2E2E38,
                      ), // polished steel/dark obsidian highlight
                      Color(0xFF14141A),
                      Color(0xFF0A0A0F),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.06), // subtle white gloss
                      Colors.white.withOpacity(0.01),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused
                  ? AppColor.accentRed
                  : Colors.white.withOpacity(0.06),
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppColor.accentRed.withOpacity(0.35),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          );

          Widget content;

          if (isPhone) {
            content = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location capsule
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: decoration,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _isPrecise
                              ? const Color(0xFF4CAF50).withOpacity(0.15)
                              : AppColor.accentRed.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: _isPrecise
                              ? const Color(0xFF4CAF50)
                              : AppColor.accentRed,
                          size: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            address,
                            key: ValueKey(address),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Time & Weather capsule
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: decoration,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Time and Date
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_filled_rounded,
                            color: Colors.white.withOpacity(0.5),
                            size: 12,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "$formattedDate, $time",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Vertical divider line
                      Container(
                        width: 1,
                        height: 12,
                        color: Colors.white.withOpacity(0.12),
                      ),
                      // Weather
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.wb_sunny_rounded,
                            color: Colors.amber,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "24°",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            content = AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: decoration,
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: _isPrecise
                        ? const Color(0xFF4CAF50)
                        : AppColor.accentRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        address,
                        key: ValueKey(address),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: Colors.white.withOpacity(0.12),
                  ),
                  const Icon(
                    Icons.access_time_filled_rounded,
                    color: Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: Colors.white.withOpacity(0.12),
                  ),
                  const Icon(
                    Icons.wb_sunny_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '24°C',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: Colors.white.withOpacity(0.12),
                  ),
                  Text(
                    formattedDate.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }

          return GestureDetector(onTap: () => "", child: content);
        },
      ),
    );
  }
}
