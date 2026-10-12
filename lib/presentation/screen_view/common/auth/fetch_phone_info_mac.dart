import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:wiseplayertizen/core/utils/tv_detector.dart';
import 'package:wiseplayertizen/core/utils/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wiseplayertizen/data/local_storage/pin_security_service.dart';
import 'package:wiseplayertizen/presentation/widgets/pin_input_dialog.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/localization/change_language_alert.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/utils/date_time_formatter.dart';
import 'package:wiseplayertizen/core/utils/loader.dart';
import 'package:wiseplayertizen/core/utils/message_dialog.dart';
import 'package:wiseplayertizen/core/utils/snackbar.dart';
import 'package:wiseplayertizen/core/widgets/custom_button.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';
import 'package:wiseplayertizen/core/widgets/laderScreen.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/end_points.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/payment%20_invoice_model.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/show_subsciption_plan.dart';
import 'package:wiseplayertizen/core/widgets/geo_location_banner.dart';

import '../../../../core/const/global_data/global_data.dart';
import '../../../../core/localization/generated/l10n.dart';
import '../../../../core/shared_pref/shared_pref.dart';
import '../../../../core/utils/exit_dialog.dart';
import '../../../../core/utils/get_device_info.dart';
import '../../bloc/api_services/api_services.dart';
import '../../bloc/connectivity_bloc/connectivity_bloc.dart';
import '../../../../core/const/global_data/global_data.dart';
import '../../../../core/localization/generated/l10n.dart';
import '../../../../core/shared_pref/shared_pref.dart';
import '../../../../core/utils/exit_dialog.dart';
import '../../../../core/utils/get_device_info.dart';
import '../../bloc/api_services/api_services.dart';
import '../../bloc/connectivity_bloc/connectivity_bloc.dart';

class FetchPhoneInfoMac extends StatefulWidget {
  static String routeName = AppRoutes.fetchPhoneInfoMac;

  const FetchPhoneInfoMac({super.key});

  @override
  State<FetchPhoneInfoMac> createState() => _FetchPhoneInfoMacState();
}

class _FetchPhoneInfoMacState extends State<FetchPhoneInfoMac>
    with TickerProviderStateMixin {
  String address = "";
  ApiService apiService = ApiService();
  String deviceMac = "";
  bool isLoading = false;
  bool isLoadingStatus = true;
  String deviceKey = "";
  bool isStatusActive = false;
  String planName = "";
  bool isAllowInApp = false;
  // Expiry date string (e.g. "Dec 31, 2026") — populated from API
  String _expiresAt = "";
  // true when the device was once known but its plan has expired / been cancelled
  bool _isPlanExpired = false;
  bool _pendingShowInvoice =
      false; // true = show dialog as soon as invoice loads
  bool _isRefreshing = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _logoAnimationController;

  @override
  void initState() {
    super.initState();
    // Green / red status-dot pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    getData();
  }

  DateTime now = DateTime.now();

  @override
  void dispose() {
    _pulseController.dispose();
    _logoAnimationController.dispose();
    super.dispose();
  }

  getData() async {
    debugPrint("fexth regtister 😀😀");
    // ── TV detection (additive, phone path unchanged) ─────────────────────
    final screenW =
        WidgetsBinding
            .instance
            .platformDispatcher
            .views
            .first
            .physicalSize
            .width /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final bool isTV = await TvDetector.isTV(screenWidthDp: screenW);
    if (isTV && mounted) {
      GoRouter.of(context).go(AppRoutes.tvHomeScreen);
      return;
    }
    // ─────────────────────────────────────────────────────────────────────

    await getDeviceInfo0();
    // Always set macAddress immediately after device info is fetched,
    // so the UI shows the MAC even before checkUserStatus() API call completes.
    final savedInfo = await SharedPref.getUserDeviceInfo();
    if ((savedInfo['mac'] as String).isNotEmpty) {
      macAddress = savedInfo['mac']!;
    }
    await checkUserStatus();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> checkUserStatus() async {
    try {
      final SharedPreferences pref = await SharedPreferences.getInstance();
      final userData1 = await SharedPref.getUserDeviceInfo();
      isStatusActive = await SharedPref.getUserDeviceStatus();

      // API 1: Boot-time Validation (Lightweight)
      final userData = await apiService.hitPostApi(
        reqData: {'fingerprint': userData1['mac']},
        endpoint: Endpoints.checkDeviceStatus,
      );

      if (userData.data?['success'] == false ||
          userData.data?['status'] == "INACTIVE") {
        pref.setString('status', "");
      }

      if (userData.data?['message'] ==
          "Device not found. Please register device first.") {
        pref.setString('status', "");
      }

      if (userData.isSuccess) {
        bool liveAllowed = (userData.data?['allowed'] ?? false) as bool;
        String liveStatus = (userData.data?['status'] ?? '') as String;
        String deviceId = userData.data?['deviceId']?.toString() ?? '';
        macAddress = userData1['mac'] ?? '';

        final tokenToStore =
            ((userData.data?['token'] ?? '').toString().isNotEmpty)
            ? userData.data!['token'] as String
            : userData1['token'] ?? '';

        // Setup initial default logic based on validation
        isStatusActive = liveStatus == 'ACTIVE';
        isAllowInApp = liveAllowed;

        String livePlan = (userData.data?['subscriptionType'] ?? '') as String;
        String rawExpiry =
            userData.data?['expiresAt'] ??
            userData.data?['expiredAt'] ??
            userData.data?['expiry'] ??
            '';

        // API 2: Subscription Status (Detailed)
        if (deviceId.isNotEmpty) {
          final subRes = await apiService.hitGetApi(
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
              isStatusActive = false;
              isAllowInApp = false;
              livePlan =
                  detailedStatus; // Display 'PAUSED' / 'CANCELLED' instead
            } else if (detailedStatus == 'ACTIVE') {
              // Only mark device active if the subscription API explicitly says ACTIVE.
              // 'TRIAL' here is a subscription *period type*, not an activation flag —
              // so a first-install unactivated device with status='TRIAL' stays INACTIVE.
              isStatusActive = true;
              isAllowInApp = true;
            }
          }
        }

        SharedPref.setValidateStatus(
          deviceId: deviceId,
          status: liveStatus,
          isAllow: isAllowInApp,
          plan: livePlan,
          token: tokenToStore,
        );

        planName = livePlan.isNotEmpty
            ? livePlan
            : (isStatusActive ? 'TRIAL' : '');

        // Parse expiry date for display
        _expiresAt = _parseExpiryDate(
          rawExpiry.toString(),
          planName,
          isStatusActive,
        );

        // Determine if the plan has expired
        final upperPlan = planName.toUpperCase();
        bool hasPastExpiry = false;
        if (rawExpiry.isNotEmpty && rawExpiry != 'null') {
          try {
            final dt = DateTime.parse(rawExpiry.toString()).toLocal();
            hasPastExpiry = dt.isBefore(DateTime.now());
          } catch (_) {}
        }

        _isPlanExpired =
            !isStatusActive &&
            (upperPlan.contains('EXPIRED') ||
                upperPlan.contains('PAUSED') ||
                upperPlan.contains('CANCELLED') ||
                (hasPastExpiry &&
                    (upperPlan.contains('TRIAL') ||
                        upperPlan.contains('ANNUAL') ||
                        upperPlan.contains('MONTHLY') ||
                        upperPlan.contains('LIFETIME'))));

        if (!isStatusActive) {
          final getDeviceKey = await apiService.hitPostApi(
            reqData: {'deviceId': userData1['mac']},
            endpoint: Endpoints.generateDeviceKeyEndpoint,
          );
          deviceKey = getDeviceKey.data?['activationKey'] ?? "";
          log("Fetched device key: $deviceKey");
        } else {
          deviceKey = '';
        }

        // Dispatch invoice fetch if paid plan
        if (planName.toUpperCase().contains("ANNUAL") ||
            planName.toUpperCase().contains("LIFETIME")) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              BlocProvider.of<WiseBloc>(context).add(PaymentInvoiceEvent());
            }
          });
        }
      } else {
        log("Failed to fetch user status: ${userData.error}");
      }
    } catch (e) {
      log('[FetchPhoneInfoMac] checkUserStatus error: $e');
    }
    if (!mounted) return;
    setState(() {
      isLoadingStatus = false;
    });
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

  /// Activation handler — mirrors the TV screen's _onActivateDevice().
  /// • Plan expired / cancelled / paused  → subscription plan screen.
  /// • Brand-new inactive device           → LoginWithMac activation screen.
  Future<void> _onActivateDevice() async {
    if (_isPlanExpired) {
      await GoRouter.of(context).push(ShowSubsciptionPlan.routeName);
      if (mounted) await checkUserStatus();
    } else {
      final result = await GoRouter.of(context)
          .push(AppRoutes.loginWithMac, extra: deviceKey);
      if (result == true && mounted) {
        await checkUserStatus();
      }
    }
  }

  Future<void> _onUploadPlaylist() async {
    if (isStatusActive && isAllowInApp) {
      GoRouter.of(context).push(AppRoutes.uploadPlaylist);
    } else {
      GoRouter.of(context).push(ShowSubsciptionPlan.routeName);
    }
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      loader(context);
      await checkUserStatus();
      if (!mounted) return;
      if (isStatusActive) {
        if (isAllowInApp) {
          GoRouter.of(context).push(AppRoutes.categoryPage);
          if (mounted) stopLoader(context);
        } else {
          stopLoader(context);
          GoRouter.of(context).push(ShowSubsciptionPlan.routeName);
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

  getDeviceInfo0() async {
    final userDeviceInfo = await getDeviceInfo();
    Map<String, dynamic> data = await SharedPref.getUserDeviceInfo();

    // Always keep macAddress updated from the device ID we just computed.
    final computedMac = userDeviceInfo['macLikeId'] ?? '';
    if (computedMac.isNotEmpty) {
      deviceMac = computedMac;
      macAddress = computedMac;
    }

    if (data['deviceSecret'].isEmpty || data['deviceSecret'] == null) {
      final res = await apiService.hitPostApi(
        reqData: {
          "deviceId": computedMac,
          "deviceModel": userDeviceInfo['model'] ?? "",
          "osVersion": userDeviceInfo['androidVersion'] ?? "",
          "platform": userDeviceInfo['plateform'] ?? "",
        },
        endpoint: Endpoints.deviceRegister,
      );
      if (kDebugMode) {
        log("api reponse data register0------> ${res.data}");
      }
      if (res.isSuccess) {
        SharedPref.setUserDeviceInfo(
          macAddress: computedMac,
          deviceId: res.data['deviceId'],
          status: "",
          token: res.data['token'] ?? "",
          deviceSecret: res.data['deviceSecret'] ?? "",
        );
      } else {
        if (res.data['status'] == 409) {
          debugPrint("😀😀😀😀😀😂");
        }
        log("Login with mac failed: ${res.error} or ");
      }
      if (!mounted) return;
      setState(() {});
    } else {
      // Device already registered. macAddress was already set above from computed value.
      // Also sync from SharedPrefs in case computed and stored differ.
      final storedMac = (data['mac'] as String? ?? '');
      if (storedMac.isNotEmpty) {
        macAddress = storedMac;
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    S s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: null,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
            children: [
              TextSpan(
                text: "Wise ",
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: "Player",
                style: TextStyle(color: AppColor.accentRed),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          (planName.toUpperCase().contains("ANNUAL") ||
                  planName.toUpperCase().contains("LIFETIME"))
              ? BlocSelector<WiseBloc, WiseState, PaymentInvoiceModel?>(
                  selector: (state) => state.paymentInvoiceSingleData,
                  builder: (context, invoiceData) {
                    return FocusableAppBarAction(
                      onPressed: () {
                        if (invoiceData == null ||
                            invoiceData.invoiceNumber == null) {
                          // Data not yet loaded — set flag + re-trigger fetch
                          setState(() => _pendingShowInvoice = true);
                          BlocProvider.of<WiseBloc>(context)
                              .add(PaymentInvoiceEvent());
                          snackBar(
                            context,
                            "Loading plan details...",
                            AppColor.accentRed,
                          );
                        } else {
                          log(
                            "the data of payment invoice is ${invoiceData.toJson()}",
                          );
                          showPaymentSuccessDialog(context, invoiceData);
                        }
                      },
                      icon: FaIcon(
                        FontAwesomeIcons.crown,
                        size: 26,
                        color: AppColor.accentRed,
                      ),
                    );
                  },
                )
              : FocusableAppBarAction(
                  onPressed: () async {
                    await GoRouter.of(context)
                        .push(ShowSubsciptionPlan.routeName);
                    if (mounted) await checkUserStatus();
                  },
                  icon: FaIcon(
                    FontAwesomeIcons.crown,
                    color: AppColor.accentRed,
                    size: 26,
                  ),
                ),
          const SizedBox(width: 5),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: isLoadingStatus
            ? Center(child: LoaderScreen(key: const ValueKey('loader')))
            : Container(
                key: const ValueKey('content'),
                decoration: const BoxDecoration(
                  gradient: AppColor.backgroundGradient,
                ),
                child: BlocListener<WiseBloc, WiseState>(
                  listenWhen: (prev, curr) =>
                      prev.paymentInvoiceSingleData == null &&
                      curr.paymentInvoiceSingleData != null,
                  listener: (context, state) {
                    // Auto-show dialog if user tapped crown while data was loading
                    if (_pendingShowInvoice &&
                        state.paymentInvoiceSingleData?.invoiceNumber != null) {
                      _pendingShowInvoice = false;
                      showPaymentSuccessDialog(
                        context,
                        state.paymentInvoiceSingleData!,
                      );
                    }
                  },
                  child: BlocListener<ConnectivityBloc, ConnectivityState>(
                    listenWhen: (previous, current) =>
                        previous.runtimeType != current.runtimeType,
                    listener: (context, state) async {
                      log("the connectivity state is $state");
                      if (state is ConnectivityDisconnected) {
                        return dialogWithoutDismisable(
                          context: context,
                          title: const Text("No Internet"),
                          content: const CText(
                            "Please check your internet connection and try again.",
                          ),
                          onTap: () {
                            BlocProvider.of<ConnectivityBloc>(context)
                                .add(CheckInterNetConnectionEvent());
                          },
                          okk: "Okk",
                        );
                      } else {
                        if (Navigator.of(
                          context,
                          rootNavigator: true,
                        ).canPop()) {
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                      }
                    },
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: buildBodyContent(s),
                      ),
                    ),
                  ), // closes BlocListener<ConnectivityBloc>
                ), // closes BlocListener<WiseBloc>
              ), // closes Container
      ), // closes AnimatedSwitcher
    );
  }

  void showPaymentSuccessDialog(
    BuildContext context,
    PaymentInvoiceModel data,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        String date = formatDate(data.createdAt.toString());
        String time = formatTimeAMPM(data.createdAt.toString());
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF151724), // Sleek dark surface
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColor.accentRed.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColor.accentRed,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        "Plan Details",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    children: [
                      _row("Invoice No", data.invoiceNumber.toString()),
                      _divider(),
                      _row("Plan", data.planDisplayName),
                      _divider(),
                      _row("Amount", "${data.amount} ${data.currency}"),
                      _divider(),
                      _row("Method", data.paymentMethod),
                      _divider(),
                      _row("Date", date),
                      _divider(),
                      _row("Time", time),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Download PDF — left, outlined
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.25),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          context.read<WiseBloc>().add(
                            DownloadInvoicePdfEvent(
                              invoiceId: data.invoiceNumber.toString(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text(
                          "Download",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // OK — right, solid brand red
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.accentRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: AppColor.accentRed.withOpacity(0.5),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "OK",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Divider(color: Colors.white.withOpacity(0.1), height: 1),
    );
  }

  Widget _row(String title, String? value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value ?? "-",
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildBodyContent(S s) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    // Responsive horizontal padding — generous on large screens, tight on phones
    final hPad = (screenW * 0.05).clamp(12.0, 28.0);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Geolocation and Time Banner
          const GeoLocationBanner(),
          // const SizedBox(height: 10),

          // // App Logo — wrapped in RepaintBoundary so its per-frame
          // // animation does NOT invalidate sibling widgets in the Column.
          // RepaintBoundary(
          //   child: AnimatedBuilder(
          //     animation: _logoAnimationController,
          //     builder: (context, child) {
          //       return Transform.translate(
          //         offset: Offset(0, 5 * (1 - _logoAnimationController.value)),
          //         child: Transform.scale(
          //           scale: 1.0 + (_logoAnimationController.value * 0.05),
          //           child: Container(
          //             decoration: BoxDecoration(
          //               shape: BoxShape.circle,
          //               boxShadow: [
          //                 BoxShadow(
          //                   color: AppColor.accentRed.withOpacity(
          //                     0.3 * _logoAnimationController.value,
          //                   ),
          //                   blurRadius: 30,
          //                   spreadRadius: 2,
          //                 ),
          //               ],
          //             ),
          //             child: child,
          //           ),
          //         ),
          //       );
          //     },
          //     child: Image.asset(
          //       "assets/images/transperentLogo.png",
          //       // Responsive logo height — 10% of screen height, capped
          //       height: (screenH * 0.10).clamp(56.0, 90.0),
          //       fit: BoxFit.contain,
          //     ),
          //   ),
          // ),
          const SizedBox(height: 12),

          // Status Card (Unified active/inactive/expired card matching TV home screen)
          _buildStatusCard(),
          const SizedBox(height: 14),

          // Action Buttons Row (FocusAutoScroll wraps this block)
          FocusAutoScroll(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double btnWidth = (constraints.maxWidth - 16) / 2;
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: btnWidth,
                          child: CustomButton(
                            backgroundColor: Colors.white.withOpacity(0.06),
                            isBorderSide: true,
                            borderColor: Colors.white.withOpacity(0.12),
                            iconColor: Colors.white,
                            icon: Icons.playlist_add_rounded,
                            child: CText(
                              s.uploadPlaylist,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            onPressed: _onUploadPlaylist,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: btnWidth,
                          child: CustomButton(
                            backgroundColor: Colors.white.withOpacity(0.06),
                            isBorderSide: true,
                            borderColor: Colors.white.withOpacity(0.12),
                            iconColor: Colors.white,
                            icon: Icons.refresh_rounded,
                            child: CText(s.refresh, color: Colors.white),
                            onPressed: _onRefresh,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: btnWidth,
                          child: CustomButton(
                            backgroundColor: Colors.white.withOpacity(0.06),
                            isBorderSide: true,
                            borderColor: Colors.white.withOpacity(0.12),
                            iconColor: Colors.white,
                            icon: Icons.language_rounded,
                            child: CText(s.language, color: Colors.white),
                            onPressed: () => showLanguageDialog(context),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: btnWidth,
                          child: CustomButton(
                            backgroundColor: Colors.white.withOpacity(0.06),
                            isBorderSide: true,
                            borderColor: Colors.white.withOpacity(0.12),
                            iconColor: Colors.white,
                            icon: Icons.power_settings_new_rounded,
                            child: const CText("Logout", color: Colors.white),
                            onPressed: () => showExitDialog(context, s),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // ── Two-column bottom: Device info (left) | QR code (right) ──
          FocusAutoScroll(child: _buildBottomInfoRow()),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Two-column bottom section:
  ///  Left  → MAC address + device info panel
  ///  Right → QR code (scan to visit website / add playlist)
  Widget _buildBottomInfoRow() {
    final bool useVerticalLayout = MediaQuery.of(context).size.width < 600;

    final deviceInfoWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section title
          Row(
            children: [
              const Icon(
                Icons.devices_rounded,
                color: AppColor.accentRed,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                'Device Info',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // MAC Address row
          _deviceInfoRow(
            icon: Icons.dns_rounded,
            label: 'MAC',
            value: macAddress.isNotEmpty ? macAddress : '—',
          ),
          const SizedBox(height: 6),
          // Plan row
          _deviceInfoRow(
            icon: Icons.workspace_premium_rounded,
            label: 'Plan',
            value: planName.isNotEmpty ? planName : 'TRIAL',
          ),
          const SizedBox(height: 6),
          // Status row
          _deviceInfoRow(
            icon: Icons.fiber_manual_record_rounded,
            label: 'Status',
            value: isStatusActive ? 'ACTIVE' : 'INACTIVE',
            valueColor: isStatusActive
                ? const Color(0xFF4CAF50)
                : const Color(0xFFF44336),
          ),
          if (_expiresAt.isNotEmpty && !_expiresAt.startsWith('null')) ...[
            const SizedBox(height: 6),
            _deviceInfoRow(
              icon: Icons.event_rounded,
              label: 'Expiry',
              value: _expiresAt,
            ),
          ],
          const SizedBox(height: 6),
          // Website row
          _deviceInfoRow(
            icon: Icons.language_rounded,
            label: 'Site',
            value: 'wise-player.com',
          ),
        ],
      ),
    );

    final qrCodeWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColor.accentRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColor.accentRed.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: AppColor.accentRed,
                size: 13,
              ),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Scan to Upload Playlist',
                  style: TextStyle(
                    color: AppColor.accentRed,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // QR Code box
        Focus(
          canRequestFocus: false,
          child: Builder(
            builder: (context) {
              final isFocused = Focus.of(context).hasFocus;
              return AnimatedScale(
                scale: isFocused ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 80),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    try {
                      final url = Uri.parse(
                        'https://wise-player.com/upload-list?mac=$macAddress',
                      );
                      if (!await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      )) {
                        ToastService.showError('Could not launch $url');
                      }
                    } catch (e) {
                      ToastService.showError('Could not launch link');
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFocused
                            ? AppColor.accentRed
                            : Colors.transparent,
                        width: isFocused ? 3.0 : 0.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isFocused
                              ? AppColor.accentRed.withOpacity(0.4)
                              : AppColor.accentRed.withOpacity(0.12),
                          blurRadius: isFocused ? 20 : 12,
                          spreadRadius: isFocused ? 5 : 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data:
                          'https://wise-player.com/upload-list?mac=$macAddress',
                      version: QrVersions.auto,
                      size: 100,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black87,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'wise-player.com',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    if (useVerticalLayout) {
      return Column(
        children: [deviceInfoWidget, const SizedBox(height: 10), qrCodeWidget],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: deviceInfoWidget),
        const SizedBox(width: 12),
        Expanded(flex: 4, child: qrCodeWidget),
      ],
    );
  }

  /// Single info row used in the device info panel.
  Widget _deviceInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: Colors.white.withOpacity(0.4)),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? Colors.white.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  /// Status card — mirrors TV screen's unified _buildStatusCard().
  /// Displays pulsing status dot, active/inactive/expired headline & subtitle,
  /// formatted expiry date with days left, device key for new devices,
  /// and trailing plan chip or Activate/Buy Premium button.
  Widget _buildStatusCard() {
    final isActive = isStatusActive;
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
      if (planName == 'PAUSED' || planName == 'CANCELLED') {
        statusHeadline = 'Subscription $planName';
        statusSubtitle = 'Please check your account or contact support.';
      } else {
        final planLabel = planName.isNotEmpty ? planName : 'Trial';
        statusHeadline = '$planLabel Expired';
        statusSubtitle = 'Tap Activate to renew your plan';
      }
    } else {
      statusHeadline = s.inactiveStatus;
      statusSubtitle = s.activateYourDevice;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderC, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: dotColor.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    blurRadius: 10 * _pulseAnim.value,
                    spreadRadius: 3 * _pulseAnim.value,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusHeadline,
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF81C784)
                        : const Color(0xFFE57373),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Show device key for brand-new devices only
                if (!isActive && !_isPlanExpired && deviceKey.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Device Key: $deviceKey',
                    style: const TextStyle(
                      color: Color(0xFFFFB300),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
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
                        color: Colors.white.withOpacity(0.4),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _expiresAt,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Active: show plan chip | Inactive/Expired: show Activate/Buy Premium button
          if (isActive) ...[
            if (planName.isNotEmpty) _ActivePlanChip(planName: planName),
          ] else ...[
            _StatusActivateButton(
              isPlanExpired: _isPlanExpired,
              onPressed: _onActivateDevice,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivePlanChip extends StatelessWidget {
  final String planName;
  const _ActivePlanChip({required this.planName});

  @override
  Widget build(BuildContext context) {
    String label = planName;
    if (planName.toUpperCase().contains('LIFETIME')) {
      label = 'LIFETIME';
    } else if (planName.toUpperCase().contains('ANNUAL')) {
      label = 'ANNUAL';
    } else if (planName.toUpperCase().contains('MONTHLY')) {
      label = 'MONTHLY';
    } else if (planName.toUpperCase().contains('TRIAL')) {
      label = 'TRIAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Text(
        label,
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

class _StatusActivateButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isPlanExpired;

  const _StatusActivateButton({
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
      canRequestFocus: false,
      child: Builder(
        builder: (ctx) {
          final isFocused = Focus.of(ctx).hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isFocused
                          ? [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.25),
                            ]
                          : [startColor, endColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isFocused
                          ? (isPlanExpired
                                ? const Color(0xFFFFB300)
                                : const Color(0xFFE57373))
                          : Colors.transparent,
                      width: isFocused ? 2.0 : 0.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: startColor.withOpacity(0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
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
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FocusAutoScroll extends StatefulWidget {
  final Widget child;
  const FocusAutoScroll({super.key, required this.child});

  @override
  State<FocusAutoScroll> createState() => _FocusAutoScrollState();
}

class _FocusAutoScrollState extends State<FocusAutoScroll> {
  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = context;
      if (Scrollable.maybeOf(ctx) == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onFocusChange: _onFocusChange,
      child: widget.child,
    );
  }
}

class FocusableAppBarAction extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;

  const FocusableAppBarAction({
    super.key,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isFocused
                      ? Colors.white.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFocused
                        ? Colors.white.withOpacity(0.3)
                        : Colors.transparent,
                    width: 1.0,
                  ),
                ),
                child: icon,
              ),
            ),
          );
        },
      ),
    );
  }
}
