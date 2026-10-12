import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/presentation/screen_view/responsive/responsive_layout.dart';

import '../../../../core/const/global_data/global_data.dart';

class SplashScreen extends StatefulWidget {
  static const String routeName = AppRoutes.splashScreen;

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  /// Completes with the animation's duration once Lottie parses the JSON.
  /// This is the single source of truth for how long the splash should stay.
  final Completer<Duration> _animDurationCompleter = Completer<Duration>();

  @override
  void initState() {
    super.initState();

    // Fade-in envelope (900ms) — purely cosmetic, does NOT control navigation.
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Run data load and animation-duration discovery in parallel.
      // Navigation only happens after BOTH are done.
      // Hard cap: 8 s — prevents any hang if onLoaded never fires
      // (e.g. corrupted asset on first install).
      await Future.any([
        _waitForAnimationAndData(),
        Future.delayed(const Duration(seconds: 8)),
      ]);

      if (mounted) {
        // ignore: use_build_context_synchronously
        GoRouter.of(context).go(ScreenLayoutScreen.routeName);
      }
    });
  }

  /// Loads user data in parallel with the Lottie animation playback.
  /// Returns only after both are complete.
  Future<void> _waitForAnimationAndData() async {
    await Future.wait([_loadUserData(), _playAnimation()]);
  }

  /// Waits for Lottie to report its duration via [onLoaded], then waits
  /// exactly that long — so navigation fires right as the last frame plays.
  Future<void> _playAnimation() async {
    // _animDurationCompleter is fulfilled by the onLoaded callback in build().
    final Duration animDuration = await _animDurationCompleter.future;
    await Future.delayed(animDuration);
  }

  Future<void> _loadUserData() async {
    final Map<String, dynamic> userdata = await SharedPref.getUserDeviceInfo();

    deviceId = userdata['deviceId'];
    macAddress = userdata['mac'];
    token = userdata['token'];

    print('📱 Device ID: $deviceId');
    print('📡 MAC Address: $macAddress');
    print('🔑 Device Token: $token');

    print('📦 Complete User Device Info: $userdata');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenW = constraints.maxWidth;
            final double screenH = constraints.maxHeight;
            final bool isLandscape = screenW > screenH;

            // The Lottie JSON is 720×405 (16:9 ratio)
            // Netflix style: logo is smaller, elegant, and dead-center.
            double lottiW, lottiH;

            if (isLandscape) {
              // TV / Landscape: logo takes ~40% of height
              lottiH = screenH * 0.40;
              lottiW = lottiH * (720 / 405);

              if (lottiW > screenW * 0.50) {
                lottiW = screenW * 0.50;
                lottiH = lottiW * (405 / 720);
              }
            } else {
              // Phone / Portrait: logo takes 60% of width
              lottiW = screenW * 0.60;
              lottiH = lottiW * (405 / 720);
            }

            return Center(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.05, 0.2, 0.8, 0.95],
                ).createShader(bounds),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0.05, 0.2, 0.8, 0.95],
                  ).createShader(bounds),
                  child: Lottie.asset(
                    'assets/images/final_logo_animation_black_bg.json',
                    width: lottiW,
                    height: lottiH,
                    fit: BoxFit.contain,
                    // medium quality saves GPU memory on low-RAM TV devices
                    filterQuality: FilterQuality.medium,
                    // repeat: false — play once, then hold the last frame.
                    // The Completer above drives navigation timing, so there
                    // is no way for the splash to loop.
                    repeat: false,
                    onLoaded: (composition) {
                      // Fulfill the Completer exactly once with the JSON duration.
                      if (!_animDurationCompleter.isCompleted) {
                        _animDurationCompleter.complete(composition.duration);
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
