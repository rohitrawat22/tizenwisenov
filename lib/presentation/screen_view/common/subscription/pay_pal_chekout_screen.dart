import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/end_points.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/auth/fetch_phone_info_mac.dart';

import '../../bloc/wise_bloc.dart';

// import 'package:get/route_manager.dart';
// import 'package:ventoutt/src/core/paypal_payment/services/paypal_services.dart';

class PayPalCheckoutScreen extends StatefulWidget {
  static const String paypalCheckoutScreen = AppRoutes.paypalCheckoutScreen;

  const PayPalCheckoutScreen({super.key});

  @override
  State<PayPalCheckoutScreen> createState() => _PayPalCheckoutScreenState();
}

class _PayPalCheckoutScreenState extends State<PayPalCheckoutScreen> {
  late InAppWebViewController webViewController;
  String address = "";
  ApiService apiService = ApiService();
  String deviceMac = "";
  String deviceKey = "";
  bool isStatusActive = false;
  String planName = "";
  bool isAllowInApp = false;
  @override
  Widget build(BuildContext context) {
    // final checkoutUrl =
    //     "https://www.sandbox.paypal.com/checkoutnow?token=${widget.orderId}";
    // "https://www.sandbox.paypal.com/checkoutnow?token=0G0438111A413623L"

    return Scaffold(
      appBar: AppBar(
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back),
        //   onPressed: () {
        //     return Navigator.pop(context, {"status": "cancel"});
        //   },
        // ),
        title: const Text("Pay with PayPal"),
      ),
      body: BlocSelector<WiseBloc, WiseState, String>(
        selector: (state) {
          return state.openPaypallUrl;
        },
        builder: (context, url) {
          return InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri.uri(Uri.parse(url))),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },

            // 🔥 PayPal Redirect Listener
            onUpdateVisitedHistory: (controller, url, androidIsReload) {
              final currentUrl = url.toString();

              debugPrint("CURRENT URL: $currentUrl");
              //     https://api.wise-player.com/api/payment/paypal/success?token=7B313716UF121723W&PayerID=XQVUTE4VG6DWC
              // log(
              //   "Payment url is kdkskj---- $currentUrl---- ${API.baseURL}paypal/success?token=",
              // );

              // PayPal Success URL
              if (currentUrl.startsWith(
                "$baseUrl/api/payment/paypal/success?token=",
              )) {
                log(
                  "Payment successfull ---------------------------------------------------",
                );
                checkUserStatus();

                return context.pop({"status": "success", "url": currentUrl});

                // return _capturePayment();
              }

              // PayPal Cancel URL
              if (currentUrl.contains("$baseUrl/api/payment/paypal/cancel")) {
                // Get.back({"status": "cancel"});
                return context.pop({"status": "cancel", "url": ""});
              }
            },
          );
        },
      ),
    );
  }

  // 🔥 Call backend for capture final payment
  _capturePayment() async {
    // final data = await PayPalService.capturePayment(widget.orderId);

    return Navigator.pop(context, {"status": "success"});
  }

  checkUserStatus() async {
    final userData1 = await SharedPref.getUserDeviceInfo();

    log("the user data is stored data====> $userData1");
    isStatusActive = await SharedPref.getUserDeviceStatus();
    // if (!isStatusActive) {

    // final userDeviceInfo = await getDeviceInfo();
    log("1");
    final userData = await apiService.hitPostApi(
      reqData: {
        'fingerprint': userData1['mac'],
        // 'deviceSecret': userData1['deviceSecret'],deviceSecret
      },
      endpoint: Endpoints.checkDeviceStatus,
    );
    log("fsafsa${userData.data}");
    debugPrint("😀😀😀😂");
    SharedPreferences pref = await SharedPreferences.getInstance();

    var data = await SharedPref.getUserDeviceInfo();
    String deviceId = data['deviceSecret'] ?? "";
    String token = data['token'] ?? "";
    if (kDebugMode) {
      log("DeviceId: $deviceId");
    }
    if (userData.data['success'] == false ||
        userData.data['status'] == "INACTIVE") {
      pref.setString('status', "");
      debugPrint("😂");
    }

    if (userData.data['message'] ==
        "Device not found. Please register device first.") {
      pref.setString('status', "");
    }
    log("checkUserStatus");
    if (userData.isSuccess) {
      deviceId = userData.data?['deviceId'] ?? "";
      macAddress = userData1['mac'] ?? "";
      token = userData.data?['token'] ?? "";

      final String liveStatus = userData.data?['status'] ?? "";
      final bool liveAllowed = userData.data?['allowed'] ?? false;

      SharedPref.setValidateStatus(
        deviceId: userData.data?['deviceId'] ?? "",
        status: liveStatus,
        isAllow: liveAllowed,
        plan: userData.data?['subscriptionType'] ?? "",
        token: ((userData.data?['token'] ?? '').toString().isNotEmpty)
            ? userData.data!['token']
            : token,
      );

      // ✅ FIX: Update isStatusActive directly from the live API response.
      // Previously this was only set from stale SharedPrefs BEFORE the API call,
      // which caused the ACTIVE→INACTIVE flash on every refresh.
      isStatusActive = liveStatus == "ACTIVE";

      isAllowInApp = liveAllowed;

      planName =
          userData.data?['subscriptionType'] ??
          ""; // TRIAL, PAID_ANNUAL, PAID_LIFETIME

      // Always fetch invoice for any paid plan so crown tap works without needing to "refresh"
      if (planName == "PAID_ANNUAL" || planName == "PAID_LIFETIME") {
        BlocProvider.of<WiseBloc>(context).add(PaymentInvoiceEvent());
      }

      log(
        "your status of device activation is $liveStatus and allowed in app is= $liveAllowed and activate plan is= $planName",
      );

      if (liveStatus == "INACTIVE") {
        final getDeviceKey = await apiService.hitPostApi(
          reqData: {'deviceId': userData1['mac']},
          endpoint: Endpoints.generateDeviceKeyEndpoint,
        );
        deviceKey = getDeviceKey.data?['activationKey'] ?? "";
        debugPrint("the device key is $deviceKey");
      } else {
        deviceKey = DateTime.now().microsecondsSinceEpoch.toString().substring(
          0,
          5,
        );
      }
    } else {
      log("Failed to fetch user status: ${userData.error}");
    }
    // } else {
    //   isStatusActive = await SharedPref.getUserDeviceStatus();
    //   final data = await SharedPref.getUserDeviceInfo();
    //   deviceMac = data['mac'] ?? "Not found";
    //   deviceKey = data['deviceKey'] ?? "Not found";
    // }
    if (!mounted) return;
    setState(() {});
  }
}
