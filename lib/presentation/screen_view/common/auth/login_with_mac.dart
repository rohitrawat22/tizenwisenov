// ─────────────────────────────────────────────────────────────────────────────
// login_with_mac.dart
//
// Activate Device Screen.
// Designed for both mobile and Android TV/Google TV.
// Fully matches the premium obsidian & crimson red brand theme:
//   • Same dark obsidian gradient background
//   • Maroon/Crimson Red colors
//   • Full D-pad/remote controller support on TV
//   • Secure server-side activation logic
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';
import 'package:wiseplayertizen/core/utils/snackbar.dart';
import 'package:wiseplayertizen/core/widgets/custom_button.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/end_points.dart';
import 'package:wiseplayertizen/core/utils/app_logo.dart';
import 'package:wiseplayertizen/core/utils/breakpoints.dart';
import 'package:wiseplayertizen/core/widgets/custom_textFormFiled.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';

// ── Brand constants ──────────────────────────────────────────────────────────
const _kRed = Color(0xFF800000); // Maroon brand red
const _kRedL = Color(0xFFE57373); // Crimson red highlight
const _kCard = Color(0xFF161620); // Card surface
const _kBorder = Color(0xFF2A2A3A); // Subtle border

class LoginWithMac extends StatefulWidget {
  final String deviceKey;
  static const String routeName = AppRoutes.loginWithMac;
  const LoginWithMac({super.key, required this.deviceKey});

  @override
  State<LoginWithMac> createState() => _LoginWithMacState();
}

class _LoginWithMacState extends State<LoginWithMac> {
  final ApiService apiService = ApiService();
  final TextEditingController macCtrl = TextEditingController();
  final TextEditingController deviceKeyCtrl = TextEditingController();

  // ── Focus Nodes for TV ─────────────────────────────────────────────────────
  final FocusNode _backFN = FocusNode(debugLabel: 'activate_back');
  final FocusNode _activateFN = FocusNode(debugLabel: 'activate_now');

  // Captured once in initState() so it is available safely in dispose()
  // (MediaQuery is not reliably accessible when the element is deactivated).
  late final bool _isPhone;
  bool _didCaptureLayout = false;
  @override
  void initState() {
    super.initState();
    // Capture device type from live MediaQuery before any async work.

    _initData();
    _wireTVFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCaptureLayout) {
      _didCaptureLayout = true;
      _isPhone = isPhoneWidth(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isPhone && mounted) {
          _activateFN.requestFocus();
        }
      });
    }
  }

  void _initData() {
    macCtrl.text = "Mac: $macAddress";
    deviceKeyCtrl.text = "Device Key: ${widget.deviceKey}";
  }

  void _wireTVFocus() {
    // back → down/right → activate button; enter → pop
    wireDpadNode(
      _backFN,
      down: _activateFN,
      right: _activateFN,
      lockUp: true,
      lockLeft: true,
      onSelect: () => Navigator.pop(context, false),
    );

    // activate → up/left → back; enter → _onActivate
    wireDpadNode(
      _activateFN,
      up: _backFN,
      left: _backFN,
      lockDown: true,
      lockRight: true,
      onSelect: _onActivate,
    );

    // Auto-focus the Activate button on startup if in TV mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isPhone && mounted) {
        _activateFN.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _backFN.dispose();
    _activateFN.dispose();
    super.dispose();
  }

  Future<void> _onActivate() async {
    final data = await SharedPref.getUserDeviceInfo();
    final activate = await apiService.hitPostApi(
      reqData: {"deviceId": data['mac'], "activationKey": widget.deviceKey},
      endpoint: Endpoints.activateAccount,
    );
    if (activate.isSuccess) {
      SharedPref.setUserDeviceStatus("ACTIVE");
      if (mounted) {
        snackBar(
          context,
          "Account Activated Successfully\nPlease refresh the page.",
          Colors.green,
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        snackBar(
          context,
          activate.data?['message'] ?? "Activation Failed",
          Colors.red,
        );
        Navigator.pop(context, false);
      }
      log("error for activation the api is ${activate.data}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        body: Container(
          height: double.infinity,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F0F18), Color(0xFF080810), Color(0xFF030306)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: _isPhone ? _buildMobileLayout() : _buildTVLayout(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile / Portrait Layout ───────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            appLogo(), 
            const SizedBox(height: 25),
            const CText(
              "Activate Device",
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 6),
            Text(
              "Activate your playlist to get started",
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            CustomTextFormFiled(
              controller: macCtrl,   
              hintText: "Device Mac",
              isEnabled: false,
              isPreFixIcon: true,
              prefixIcon: Icon(
                Icons.important_devices_rounded,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            CustomTextFormFiled(
              controller: deviceKeyCtrl,
              isEnabled: false,
              hintText: "Device key",
              isPreFixIcon: true,
              prefixIcon: Icon(
                Icons.key_rounded,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 35),
            CustomButton(
              gradient: const LinearGradient(
                colors: [_kRed, Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              child: const CText("Activate Now", fontWeight: FontWeight.bold),
              onPressed: _onActivate,
            ),
          ],
        ),
      ),
    );
  }

  // ── TV / Landscape Layout 
  Widget _buildTVLayout() {
    // Compute live width — never stale after rotation.
    final double tvCardWidth = (MediaQuery.sizeOf(context).width * 0.55).clamp(
      320.0,
      640.0,
    );
    return Container(
      width: tvCardWidth,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(0.12),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Back Button + Logo
          Row(
            children: [
              _TVBackButton(
                focusNode: _backFN,
                onPressed: () => Navigator.pop(context, false),
              ),
              const SizedBox(width: 20),
              appLogo(),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _kRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kRed.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: _kRedL, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'SECURE ACTIVATION',
                      style: TextStyle(
                        color: _kRedL,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Title & Description
          const Text(
            "Activate Device",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Link and activate your playlist from your mobile/PC using the codes below",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 24),

          // Display Fields (Mac & Key) side by side
          Row(
            children: [
              Expanded(
                child: _buildTVDisplayField(
                  icon: Icons.important_devices_rounded,
                  label: "DEVICE MAC",
                  value: macAddress,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTVDisplayField(
                  icon: Icons.key_rounded,
                  label: "DEVICE KEY",
                  value: widget.deviceKey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Bottom Action Button
          _TVActivateButton(focusNode: _activateFN, onPressed: _onActivate),
        ],
      ),
    );
  }

  Widget _buildTVDisplayField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kRedL, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV Back Button Widget
// ─────────────────────────────────────────────────────────────────────────────
class _TVBackButton extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _TVBackButton({required this.focusNode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedScale(
              scale: focused ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: focused
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: focused ? _kRedL : Colors.white.withOpacity(0.1),
                    width: focused ? 2.0 : 1.0,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: _kRed.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TV Activate Button Widget
// ─────────────────────────────────────────────────────────────────────────────
class _TVActivateButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _TVActivateButton({required this.focusNode, required this.onPressed});

  @override
  State<_TVActivateButton> createState() => _TVActivateButtonState();
}

class _TVActivateButtonState extends State<_TVActivateButton> {
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
    return AnimatedScale(
      scale: _focused ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF800000), Color(0xFFB71C1C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused ? _kRedL : Colors.transparent,
            width: _focused ? 2.5 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: _focused
                  ? _kRedL.withOpacity(0.5)
                  : _kRed.withOpacity(0.3),
              blurRadius: _focused ? 24 : 12,
              spreadRadius: _focused ? 3 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          focusNode: widget.focusNode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: widget.onPressed,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Activate Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
