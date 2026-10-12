import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/utils/breakpoints.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/auth/fetch_phone_info_mac.dart';

class ScreenLayoutScreen extends StatelessWidget {
  static const String routeName = AppRoutes.screenLayout;

  const ScreenLayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Use live constraints — never write to a shared global.
          log(
            "device width: ${constraints.maxWidth}  height: ${constraints.maxHeight}",
          );

          // Determine device type from live constraints for future branching.
          // Both mobile and TV/tablet currently use the same entry screen.
          final DeviceType deviceType =
              constraints.maxWidth < Breakpoints.mobile
              ? DeviceType.mobile
              : DeviceType.tablet;
          log("deviceType: $deviceType");

          return const FetchPhoneInfoMac();
        },
      ),
    );
  }
}
