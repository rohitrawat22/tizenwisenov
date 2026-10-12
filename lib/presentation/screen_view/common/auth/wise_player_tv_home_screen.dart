// ─────────────────────────────────────────────────────────────────────────────
// wise_player_tv_home_screen.dart
//
// Android TV / Google TV home screen for WisePlayer IPTV.
// ADDITIVE ONLY — does NOT modify any existing phone layout.
//
// Features
//   • TV-detection guard: only rendered when isTV == true
//   • D-pad / remote navigation via explicit FocusNode graph
//   • Scale-up + border-glow focus highlight on every focusable element
//   • ~5 % overscan safe-area padding
//   • 10-foot UI text sizes, large tap targets
//   • Pulsing green status dot animation
//   • Centered QR code (scan / tap to open upload URL)
//   • 2 × 2 action grid: Upload Playlist, Refresh, Language, Logout
//   • Bottom platform banner
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wiseplayertizen/data/local_storage/pin_security_service.dart';
import 'package:wiseplayertizen/presentation/widgets/pin_input_dialog.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/localization/change_language_alert.dart';
import 'package:wiseplayertizen/core/localization/generated/l10n.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';
import 'package:wiseplayertizen/core/utils/exit_dialog.dart';
import 'package:wiseplayertizen/core/utils/get_device_info.dart';
import 'package:wiseplayertizen/core/utils/loader.dart';
import 'package:wiseplayertizen/core/utils/message_dialog.dart';
import 'package:wiseplayertizen/core/utils/toast_service.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';
import 'package:wiseplayertizen/location.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/end_points.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/show_subsciption_plan.dart';

// ── Brand constants ──────────────────────────────────────────────────────────

/// Maroon brand red used throughout this screen.
const _kRed = Color(0xFF800000);

/// Card surface — deep charcoal.
const _kCard = Color(0xFF161620);

/// Subtle border colour for unfocused cards.
const _kBorder = Color(0xFF2A2A3A);

/// Overscan safe-zone padding (≈ 5 % of a typical TV screen edge).
const double _kSafe = 40.0;

// ─────────────────────────────────────────────────────────────────────────────

class WisePlayerTVHomeScreen extends StatefulWidget {
  static const String routeName = AppRoutes.tvHomeScreen;

  const WisePlayerTVHomeScreen({super.key});

  @override
  State<WisePlayerTVHomeScreen> createState() => _WisePlayerTVHomeScreenState();
}

class _WisePlayerTVHomeScreenState extends State<WisePlayerTVHomeScreen>
    with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────

  final ApiService _apiService = ApiService();

  String _locationText = 'Fetching location…';
  bool _isLocationPrecise = false;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  bool _isStatusActive = false;
  bool _isLoadingStatus = true;
  String _planName = '';
  bool _isAllowInApp = false;
  String _deviceKey = '';
  // Expiry date string (e.g. "Dec 31, 2026") — populated from API
  String _expiresAt = '';
  // Whether plan is expired but device was once known (trial ended, plan lapsed)
  bool _isPlanExpired = false;

  // ── Animations ────────────────────────────────────────────────────────────

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  late final AnimationController _logoGlowController;
  late final Animation<double> _logoGlowAnim;

  // ── Focus nodes (D-pad navigation graph) ─────────────────────────────────
  //
  //  Layout (status bar):
  //    [  location / time / date  ]  [ ★ Premium ]
  //  Layout (left column):
  //    [Upload Playlist]   [Refresh   ]
  //    [Language (EN)  ]   [Logout    ]
  //  Layout (right column):
  //    [       QR Code (centre)       ]

  final FocusNode _locationFN = FocusNode(debugLabel: 'location');
  final FocusNode _premiumFN = FocusNode(debugLabel: 'premium');
  final FocusNode _uploadFN = FocusNode(debugLabel: 'upload');
  final FocusNode _refreshFN = FocusNode(debugLabel: 'refresh');
  final FocusNode _languageFN = FocusNode(debugLabel: 'language');
  final FocusNode _logoutFN = FocusNode(debugLabel: 'logout');
  final FocusNode _qrFN = FocusNode(debugLabel: 'qr');
  final FocusNode _activateFN = FocusNode(debugLabel: 'activate_now');

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _isLoadingStatus = true;

    // Green status-dot pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Logo ambient glow
    _logoGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _logoGlowAnim = Tween<double>(begin: 0.15, end: 0.5).animate(
      CurvedAnimation(parent: _logoGlowController, curve: Curves.easeInOut),
    );

    // Clock tick — minute-level accuracy is sufficient for TV display.
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    _wireFocusGraph();
    _initData();

    // Hand off initial focus after the first frame is drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLoadingStatus) {
        if (_isStatusActive) {
          _uploadFN.requestFocus();
        } else {
          _activateFN.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _logoGlowController.dispose();
    _clockTimer?.cancel();
    for (final fn in [
      _premiumFN,
      _uploadFN,
      _refreshFN,
      _languageFN,
      _logoutFN,
      _qrFN,
      _activateFN,
      _locationFN,
    ]) {
      fn.dispose();
    }
    super.dispose();
  }

  // ── D-pad navigation graph ────────────────────────────────────────────────

  void _wireFocusGraph() {
    final bool active = _isStatusActive;

    // ★ Premium badge in status bar — top-right
    wireDpadNode(
      _premiumFN,
      down: active ? _refreshFN : _activateFN,
      left: _locationFN,
      lockUp: true,
      lockRight: true,
      onSelect: _onGoPremium,
    );

    // Info bar (location + time + date) — top-left
    wireDpadNode(
      _locationFN,
      down: active ? _uploadFN : _activateFN,
      right: _premiumFN,
      lockUp: true,
      lockLeft: true,
    );

    // Dynamic activate node (Buy Premium / Activate Now)
    if (!active) {
      wireDpadNode(
        _activateFN,
        up: _locationFN,
        down: _uploadFN,
        left: _locationFN,
        right: _qrFN,
        onSelect: _onActivateDevice,
      );
    }

    // 2×2 action grid
    wireDpadNode(
      _uploadFN,
      right: _refreshFN,
      down: _languageFN,
      up: active ? _locationFN : _activateFN,
      lockLeft: true,
      onSelect: _onUploadPlaylist,
    );

    wireDpadNode(
      _refreshFN,
      left: _uploadFN,
      down: _logoutFN,
      up: active ? _premiumFN : _activateFN,
      lockRight: true,
      onSelect: _onRefresh,
    );

    wireDpadNode(
      _languageFN,
      up: _uploadFN,
      right: _logoutFN,
      down: _qrFN,
      lockLeft: true,
      onSelect: _onLanguage,
    );

    wireDpadNode(
      _logoutFN,
      up: _refreshFN,
      left: _languageFN,
      down: _qrFN,
      lockRight: true,
      onSelect: _onLogout,
    );

    // QR section at the bottom
    wireDpadNode(
      _qrFN,
      up: _languageFN,
      lockDown: true,
      lockLeft: true,
      lockRight: true,
      onSelect: _onQrTap,
    );
  }

  // ── Data helpers ──────────────────────────────────────────────────────────

  Future<void> _initData() async {
    await _fetchDeviceInfo();
    await _checkUserStatus();
    if (mounted) setState(() {});
  }

  Future<void> _fetchDeviceInfo() async {
    debugPrint('🚀 ========== TV DEVICE INFO START ==========');

    final info = await getDeviceInfo();

    final computed = info['macLikeId'] ?? '';

    // 📱 Print device information
    debugPrint('📱 Device Model: ${info['model']}');
    debugPrint('🤖 Android Version: ${info['androidVersion']}');
    debugPrint('💻 Platform: ${info['plateform']}');
    debugPrint('🆔 Computed Device ID: $computed');

    if (computed.isNotEmpty) {
      macAddress = computed;
      debugPrint('📡 Updated MAC Address: $macAddress');
    }

    // 📦 Fetch saved device information
    final saved = await SharedPref.getUserDeviceInfo();

    debugPrint('📦 Saved Device Info: $saved');
    debugPrint('🆔 Saved Device ID: ${saved['deviceId']}');
    debugPrint('📡 Saved MAC Address: ${saved['mac']}');
    debugPrint('🔑 Saved Token: ${saved['token']}');
    debugPrint('🔐 Saved Device Secret: ${saved['deviceSecret']}');

    final storedMac = saved['mac'] as String? ?? '';

    if (storedMac.isNotEmpty) {
      macAddress = storedMac;
      debugPrint('✅ Using Saved MAC Address: $macAddress');
    }

    // 🔐 Check whether device registration is required
    if (saved['deviceSecret'] == null ||
        (saved['deviceSecret'] as String).isEmpty) {
      debugPrint('⚠️ Device Secret Missing. Starting Registration...');
      debugPrint(
        '📤 Registration Request: ${{"deviceId": computed, "deviceModel": info['model'] ?? "", "osVersion": info['androidVersion'] ?? "", "platform": info['plateform'] ?? ""}}',
      );

      final res = await _apiService.hitPostApi(
        reqData: {
          "deviceId": computed,
          "deviceModel": info['model'] ?? "",
          "osVersion": info['androidVersion'] ?? "",
          "platform": info['plateform'] ?? "",
        },
        endpoint: Endpoints.deviceRegister,
      );

      // 📥 Print API response
      if (kDebugMode) {
        log('📥 TV Device Registration Response: ${res.data}');
        debugPrint('📊 API Success: ${res.isSuccess}');
        debugPrint('❌ API Error: ${res.error}');
      }

      if (res.isSuccess) {
        debugPrint('🎉 TV Device Registered Successfully!');
        debugPrint('🆔 Registered Device ID: ${res.data['deviceId']}');
        debugPrint('🔑 Received Token: ${res.data['token']}');
        debugPrint('🔐 Received Device Secret: ${res.data['deviceSecret']}');

        await SharedPref.setUserDeviceInfo(
          macAddress: computed,
          deviceId: res.data['deviceId'] ?? "",
          status: "",
          token: res.data['token'] ?? "",
          deviceSecret: res.data['deviceSecret'] ?? "",
        );

        debugPrint('💾 Device information saved successfully.');

        // 🔍 Print updated saved information
        final updated = await SharedPref.getUserDeviceInfo();
        debugPrint('📦 Updated Saved Device Info: $updated');
        debugPrint('🆔 Updated Device ID: ${updated['deviceId']}');
        debugPrint('📡 Updated MAC Address: ${updated['mac']}');
        debugPrint('🔑 Updated Token: ${updated['token']}');
        debugPrint('🔐 Updated Device Secret: ${updated['deviceSecret']}');
      } else {
        debugPrint('🚫 TV Device Registration Failed!');
        debugPrint('📛 Error: ${res.error}');
        log('TV Login with MAC failed: ${res.error}');
      }
    } else {
      debugPrint('✅ TV Device Already Registered.');
      debugPrint('🔐 Existing Device Secret Found.');
    }

    debugPrint('🏁 ========== TV DEVICE INFO END ==========');
  }

  Future<void> _checkUserStatus() async {
    try {
      final userData = await SharedPref.getUserDeviceInfo();
      _isStatusActive = await SharedPref.getUserDeviceStatus();

      // API 1: Boot-time Validation (Lightweight)
      final res = await _apiService.hitPostApi(
        reqData: {'fingerprint': userData['mac']},
        endpoint: Endpoints.checkDeviceStatus,
      );

      if (res.isSuccess) {
        bool liveAllowed = (res.data?['allowed'] ?? false) as bool;
        String liveStatus = (res.data?['status'] ?? '') as String;

        // Setup initial default logic based on validation
        _isStatusActive = liveStatus == 'ACTIVE';
        _isAllowInApp = liveAllowed;

        final deviceId = res.data?['deviceId']?.toString() ?? '';
        final tokenToStore = ((res.data?['token'] ?? '').toString().isNotEmpty)
            ? res.data!['token'] as String
            : userData['token'] ?? '';

        String livePlan = (res.data?['subscriptionType'] ?? '') as String;
        String rawExpiry =
            res.data?['expiresAt'] ??
            res.data?['expiredAt'] ??
            res.data?['expiry'] ??
            '';

        // API 2: Subscription Status (Detailed)
        if (deviceId.isNotEmpty) {
          final subRes = await _apiService.hitGetApi(
            endpoint: '${Endpoints.subscriptionStatus}?deviceId=$deviceId',
          );
          if (subRes.isSuccess && subRes.data != null) {
            final subData = subRes.data;
            livePlan =
                subData['planName'] ??
                subData['type'] ??
                livePlan; // Prefer planName, fallback to type
            rawExpiry = subData['endDate'] ?? rawExpiry;

            // Also override status if it's explicitly CANCELLED/PAUSED from detailed API
            final detailedStatus = subData['status'] ?? '';
            if (detailedStatus == 'PAUSED' || detailedStatus == 'CANCELLED') {
              _isStatusActive = false;
              _isAllowInApp = false;
              livePlan =
                  detailedStatus; // Display 'PAUSED' / 'CANCELLED' instead
            } else if (detailedStatus == 'ACTIVE') {
              // Only mark device active if the subscription API explicitly says ACTIVE.
              // 'TRIAL' here is a subscription *period type*, not an activation flag —
              // so a first-install unactivated device with status='TRIAL' stays INACTIVE.
              _isStatusActive = true;
              _isAllowInApp = true;
            }
          }
        }

        SharedPref.setValidateStatus(
          deviceId: deviceId,
          status: liveStatus,
          isAllow: _isAllowInApp,
          plan: livePlan,
          token: tokenToStore,
        );

        _planName = livePlan.isNotEmpty
            ? livePlan
            : (_isStatusActive ? 'TRIAL' : '');

        // Parse expiry date for display
        _expiresAt = _parseExpiryDate(
          rawExpiry.toString(),
          _planName,
          _isStatusActive,
        );

        // Determine if the plan has expired
        final upperPlan = _planName.toUpperCase();

        bool hasPastExpiry = false;
        if (rawExpiry.isNotEmpty && rawExpiry != 'null') {
          try {
            final dt = DateTime.parse(rawExpiry.toString()).toLocal();
            hasPastExpiry = dt.isBefore(DateTime.now());
          } catch (_) {}
        }

        _isPlanExpired =
            !_isStatusActive &&
            (upperPlan.contains('EXPIRED') ||
                upperPlan.contains('PAUSED') ||
                upperPlan.contains('CANCELLED') ||
                (hasPastExpiry &&
                    (upperPlan.contains('TRIAL') ||
                        upperPlan.contains('ANNUAL') ||
                        upperPlan.contains('MONTHLY') ||
                        upperPlan.contains('LIFETIME'))));

        if (!_isStatusActive) {
          final getDeviceKey = await _apiService.hitPostApi(
            reqData: {'deviceId': userData['mac']},
            endpoint: Endpoints.generateDeviceKeyEndpoint,
          );
          _deviceKey = getDeviceKey.data?['activationKey'] ?? '';
          log("Fetched TV device key: $_deviceKey");
        } else {
          _deviceKey = '';
        }

        _wireFocusGraph();
        if (mounted) {
          if (_isStatusActive) {
            _uploadFN.requestFocus();
          } else {
            _activateFN.requestFocus();
          }
        }
      }
    } catch (e) {
      log('[TVHomeScreen] _checkUserStatus: $e');
    }
    if (mounted) setState(() {});
  }

  /// Format a raw ISO date string and append days left based on plan type.
  String _parseExpiryDate(String raw, String planName, bool isActive) {
    if (planName.toUpperCase().contains('LIFETIME')) {
      return 'Plan: Lifetime Premium';
    }
    if (planName.toUpperCase() == 'PAUSED' ||
        planName.toUpperCase() == 'CANCELLED') {
      return 'Subscription has been paused/cancelled.';
    }
    if (raw.isEmpty || raw == 'null') return '';

    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final formattedDate = '${months[dt.month - 1]} ${dt.day}, ${dt.year}';

      final now = DateTime.now();
      final difference = dt.difference(now).inDays;

      if (isActive) {
        if (planName.toUpperCase().contains('TRIAL')) {
          return 'Trial ends on: $formattedDate (${difference > 0 ? difference : 0} days left)';
        }
        return 'Expires on: $formattedDate (${difference > 0 ? difference : 0} days left)';
      } else {
        return 'Expired on: $formattedDate';
      }
    } catch (_) {
      return raw;
    }
  }

  // Future<void> _fetchLocation() async {
  //   try {
  //     final data = await LocationService.getCurrentLocationWithAddress()
  //         .timeout(const Duration(seconds: 15), onTimeout: () => null);
  //     if (mounted) {
  //       final raw = data?['address'] as String? ?? '';
  //       final isPrecise = (data?['precise'] ?? false) as bool;
  //       setState(() {
  //         _isLocationPrecise = isPrecise;
  //         _locationText = (raw.isNotEmpty && raw != '❌ Address not found')
  //             ? raw.replaceAll(' - ', '').replaceAll('  ', ' ').trim()
  //             : 'Unknown Location';
  //       });
  //     }
  //   } catch (_) {
  //     if (mounted) setState(() => _locationText = 'Unknown Location');
  //   }
  // }

  // ── Action handlers ───────────────────────────────────────────────────────

  Future<void> _onUploadPlaylist() async {
    if (_isStatusActive && _isAllowInApp) {
      GoRouter.of(context).push(AppRoutes.uploadPlaylist);
    } else {
      GoRouter.of(context).push(AppRoutes.tvSubscriptionPlan);
    }
  }

  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      loader(context);
      await _checkUserStatus();
      if (!mounted) return;
      if (_isStatusActive) {
        if (_isAllowInApp) {
          GoRouter.of(context).push(AppRoutes.categoryPage);
          if (mounted) stopLoader(context);
        } else {
          stopLoader(context);
          GoRouter.of(context).push(AppRoutes.tvSubscriptionPlan);
        }
      } else {
        stopLoader(context);
        messageDialog(
          context: context,
          title: const Text('Activate'),
          content: const CText('Please activate your account'),
          onTap: () => Navigator.maybePop(context),
          okk: 'OK',
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _onLanguage() => showLanguageDialog(context);

  void _onLogout() => showExitDialog(context, S.of(context));

  Future<void> _onGoPremium() async {
    final result = await GoRouter.of(context)
        .push(AppRoutes.tvSubscriptionPlan);
    // Refresh device status when returning from the subscription screen so plan
    // name and expiry are updated immediately on the home card.
    if (mounted) await _checkUserStatus();
  }

  Future<void> _onActivateDevice() async {
    if (_isPlanExpired) {
      // Plan has expired (trial ended / subscription lapsed) →
      // redirect to Buy Premium instead of device-key activation.
      final result = await GoRouter.of(context)
          .push(AppRoutes.tvSubscriptionPlan);
      if (mounted) await _checkUserStatus();
    } else {
      // Device never activated — show device key activation flow.
      final result = await GoRouter.of(context)
          .push(AppRoutes.loginWithMac, extra: _deviceKey);
      if (result == true) {
        await _checkUserStatus();
      }
    }
  }

  Future<void> _onQrTap() async {
    final url = Uri.parse(
      'https://wise-player.com/upload-list?mac=$macAddress',
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        ToastService.showError('Could not open link');
      }
    } catch (_) {
      ToastService.showError('Could not open link');
    }
  }

  // ── Root build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Always LTR — prevents Arabic RTL from inverting the entire layout.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F0F18), Color(0xFF080810), Color(0xFF030306)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(_kSafe),
              child: Column(
                children: [
                  _buildStatusRow(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Left column ──────────────────────────────────────
                        Expanded(
                          flex: 55,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAppHeaderCard(),
                                const SizedBox(height: 14),
                                _buildStatusCard(),
                                const SizedBox(height: 18),
                                _buildActionGrid(),
                                const SizedBox(height: 16),
                                _buildBottomBanner(),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 28),

                        // ── Right column: QR ─────────────────────────────────
                        Expanded(flex: 45, child: _buildQrSection()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Status row ─────────────────────────────────────────────────────────

  Widget _buildStatusRow() {
    final time = DateFormat('HH:mm').format(_now);
    final date = DateFormat('EEE d MMM').format(_now).toUpperCase();

    return Row(
      children: [
        // ── Info bar (location + time + date) ──
        Expanded(
          child: Focus(
            focusNode: _locationFN,
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
                return GestureDetector(
                  onTap: () {},
                  child: AnimatedScale(
                    scale: isFocused ? 1.02 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isFocused ? Colors.white : _kBorder,
                          width: isFocused ? 2 : 1,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: _isLocationPrecise
                                ? const Color(0xFF4CAF50)
                                : _kRed,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationText,
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
                          _vDivider(),
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
                          _vDivider(),
                          const Icon(
                            Icons.wb_sunny_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '30°C',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          _vDivider(),
                          Text(
                            date,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 14),

        // ── ★ Go Premium — top-right crown button ──
        _TVPremiumButton(focusNode: _premiumFN, onPressed: _onGoPremium),
      ],
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 14),
    color: Colors.white.withOpacity(0.12),
  );

  // ── App header card ────────────────────────────────────────────────────

  Widget _buildAppHeaderCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(0.1),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo with animated ambient glow
          AnimatedBuilder(
            animation: _logoGlowAnim,
            builder: (_, child) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kRed.withOpacity(_logoGlowAnim.value),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: child,
            ),
            child: Image.asset(
              'assets/images/transperentLogo.png',
              height: 56,
              width: 56,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kRed,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WisePlayer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'IPTV Player',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),

          // Plan badge — show plan name
          _PlanBadge(planName: _planName),
        ],
      ),
    );
  }

  // ── Status card ────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final isActive = _isStatusActive;
    final dotColor = isActive
        ? const Color(0xFF4CAF50)
        : const Color(0xFFF44336);
    final cardColor = isActive
        ? const Color(0xFF091A10)
        : const Color(0xFF1A0909);
    final borderC = isActive
        ? const Color(0xFF2E7D52).withOpacity(0.45)
        : const Color(0xFF7D2E2E).withOpacity(0.45);

    final s = S.of(context);

    // Build a human-readable status headline
    String statusHeadline;
    String statusSubtitle;
    if (isActive) {
      statusHeadline = s.activeStatus;
      statusSubtitle = s.deviceIsStreaming;
    } else if (_isPlanExpired) {
      if (_planName == 'PAUSED' || _planName == 'CANCELLED') {
        statusHeadline = 'Subscription $_planName';
        statusSubtitle = 'Please check your account or contact support.';
      } else {
        final planLabel = _planName.isNotEmpty ? _planName : 'Trial';
        statusHeadline = '$planLabel Expired';
        statusSubtitle = 'Tap Activate to renew your plan';
      }
    } else {
      statusHeadline = s.inactiveStatus;
      statusSubtitle = s.activateYourDevice;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderC, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: dotColor.withOpacity(0.1),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulsing dot
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withOpacity(_pulseAnim.value),
                    blurRadius: 12 * _pulseAnim.value,
                    spreadRadius: 4 * _pulseAnim.value,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusHeadline,
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF81C784)
                        : const Color(0xFFE57373),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Show device key for brand-new devices only
                if (!isActive && !_isPlanExpired && _deviceKey.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Device Key: $_deviceKey',
                    style: const TextStyle(
                      color: Color(0xFFFFB300),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
                // Show expiry info when active or expired but with known expiry date
                if (_expiresAt.isNotEmpty &&
                    !_expiresAt.startsWith('null')) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        color: Colors.white.withOpacity(0.35),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _expiresAt,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Active: show plan chip | Inactive/Expired: show Activate/Buy Premium button
          if (isActive) ...[
            if (_planName.isNotEmpty) _ActivePlanChip(planName: _planName),
          ] else ...[
            _TVStatusActivateButton(
              focusNode: _activateFN,
              isPlanExpired: _isPlanExpired,
              onPressed: _onActivateDevice,
            ),
          ],
        ],
      ),
    );
  }

  // ── 2 × 2 action grid ─────────────────────────────────────────────────

  Widget _buildActionGrid() {
    final s = S.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TVActionButton(
                focusNode: _uploadFN,
                icon: Icons.playlist_add_rounded,
                label: s.uploadPlaylist,
                onPressed: _onUploadPlaylist,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _TVActionButton(
                focusNode: _refreshFN,
                icon: Icons.refresh_rounded,
                label: s.refresh,
                onPressed: _onRefresh,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _TVActionButton(
                focusNode: _languageFN,
                icon: Icons.language_rounded,
                label: s.language,
                onPressed: _onLanguage,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _TVActionButton(
                focusNode: _logoutFN,
                icon: Icons.power_settings_new_rounded,
                label: s.exit,
                isDestructive: true,
                onPressed: _onLogout,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── QR section ─────────────────────────────────────────────────────────

  Widget _buildQrSection() {
    final qrUrl = 'https://wise-player.com/upload-list?mac=$macAddress';

    final s = S.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _kRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _kRed.withOpacity(0.35), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFFE57373),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  s.scanOrTapQr,
                  style: const TextStyle(
                    color: Color(0xFFE57373),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // QR card with focus glow
          _TVFocusable(
            focusNode: _qrFN,
            onPressed: _onQrTap,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kRed.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: QrImageView(
                data: qrUrl,
                version: QrVersions.auto,
                size: 210,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF800000),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF800000),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // MAC label
          Text(
            s.deviceMacAddress,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            macAddress.isNotEmpty ? macAddress : '—',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(height: 14),

          // Tap hint
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                color: Color(0xFFE57373),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                s.scanOrTapHint,
                style: TextStyle(
                  color: const Color(0xFFE57373).withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom banner ──────────────────────────────────────────────────────

  Widget _buildBottomBanner() {
    final s = S.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kRed.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kRed.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.tv_rounded, color: Color(0xFFE57373), size: 16),
          const SizedBox(width: 8),
          Text(
            s.optimizedTvOnly,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TVPremiumButton — Compact, animated crown badge for the top-right
// status bar. Glows gold on focus with a subtle scale-up.
// ─────────────────────────────────────────────────────────────────────────────

class _TVPremiumButton extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;

  const _TVPremiumButton({required this.focusNode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          const gold = Color(0xFFFFB300);
          const darkGold = Color(0xFF8B6914);

          return GestureDetector(
            onTap: onPressed,
            child: AnimatedScale(
              scale: focused ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: focused
                        ? [gold.withOpacity(0.3), gold.withOpacity(0.12)]
                        : [gold.withOpacity(0.08), gold.withOpacity(0.03)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: focused ? gold : gold.withOpacity(0.25),
                    width: focused ? 2.5 : 1.2,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: gold.withOpacity(0.55),
                            blurRadius: 24,
                            spreadRadius: 3,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: gold.withOpacity(0.08),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: focused ? gold : gold.withOpacity(0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PRO',
                      style: TextStyle(
                        color: focused ? gold : gold.withOpacity(0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
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
// _PlanBadge
// ─────────────────────────────────────────────────────────────────────────────

class _PlanBadge extends StatelessWidget {
  final String planName;
  const _PlanBadge({required this.planName});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    if (planName.contains('ANNUAL') || planName.contains('MONTHLY')) {
      label = 'PRO';
      color = const Color(0xFFFFB300);
    } else if (planName.contains('LIFETIME')) {
      label = 'PRO';
      color = const Color(0xFFFFB300);
    } else if (planName == 'TRIAL') {
      label = 'TRIAL';
      color = Colors.blue;
    } else if (planName == 'EXPIRED' ||
        planName == 'PAUSED' ||
        planName == 'CANCELLED') {
      label = 'FREE';
      color = Colors.grey;
    } else {
      label = planName.isEmpty ? 'FREE' : planName;
      color = Colors.grey;
    }

    final displayColor = color == _kRed ? const Color(0xFFE57373) : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: displayColor,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TVActionButton
// Large, D-pad focusable button for the 2 × 2 action grid.
// Visible scale-up + border-glow on focus for 10-foot UI clarity.
// ─────────────────────────────────────────────────────────────────────────────

class _TVActionButton extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _TVActionButton({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = isDestructive ? const Color(0xFFE57373) : Colors.white;

    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          final glowColor = isDestructive ? const Color(0xFFE57373) : _kRed;

          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 78,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: focused
                    ? (isDestructive
                          ? const Color(0xFF5A0808)
                          : glowColor.withOpacity(0.2))
                    : (isDestructive
                          ? const Color(0xFF1A0505)
                          : Colors.white.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: focused
                      ? (isDestructive ? const Color(0xFFE57373) : Colors.white)
                      : Colors.white.withOpacity(0.09),
                  width: focused ? 2.5 : 1.0,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: glowColor.withOpacity(0.45),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: accent, size: 26),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TVFocusable
// Wraps the QR code card with scale + border-glow focus treatment.
// ─────────────────────────────────────────────────────────────────────────────

class _TVFocusable extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final Widget child;

  const _TVFocusable({
    required this.focusNode,
    required this.onPressed,
    required this.child,
  });

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
              scale: focused ? 1.07 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: focused ? _kRed : Colors.transparent,
                    width: focused ? 3.5 : 0,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: _kRed.withOpacity(0.55),
                            blurRadius: 32,
                            spreadRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: child,
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
// _ActivePlanChip — compact chip shown in the status card when device is ACTIVE
// ─────────────────────────────────────────────────────────────────────────────
class _ActivePlanChip extends StatelessWidget {
  final String planName;
  const _ActivePlanChip({required this.planName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Text(
        planName,
        style: TextStyle(
          color: Colors.white.withOpacity(0.75),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TVStatusActivateButton — TV focusable button inside status card.
// Shows 'Buy Premium' (gold) when plan is expired, 'Activate Now' (red) for
// brand-new devices.
// ─────────────────────────────────────────────────────────────────────────────
class _TVStatusActivateButton extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final bool isPlanExpired;

  const _TVStatusActivateButton({
    required this.focusNode,
    required this.onPressed,
    this.isPlanExpired = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color startColor = isPlanExpired
        ? const Color(0xFFB8860B) // dark gold
        : const Color(0xFF800000); // maroon
    final Color endColor = isPlanExpired
        ? const Color(0xFFFFB300) // bright gold
        : const Color(0xFFB71C1C); // deep red
    final IconData btnIcon = isPlanExpired
        ? Icons.workspace_premium_rounded
        : Icons.flash_on_rounded;
    final String btnLabel = isPlanExpired ? 'Buy Premium' : 'Activate Now';

    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;

          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: focused
                      ? [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.15),
                        ]
                      : [startColor, endColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focused
                      ? (isPlanExpired
                            ? const Color(0xFFFFB300)
                            : const Color(0xFFE57373))
                      : Colors.transparent,
                  width: focused ? 2.0 : 0.0,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: startColor.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(btnIcon, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    btnLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
