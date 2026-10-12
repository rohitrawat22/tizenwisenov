class AppRoutes {
  static const String screenLayout = '/screenLayout';
  static const String splashScreen = '/';
  // TV-only home screen — additive route, never shown on phone.
  static const String tvHomeScreen = '/tv-home';
  static const String dashboard = '/dashboard';
  static const String webDashboard = '/web-dashboard';
  static const String loginWithMac = '/login-with-mac';
  static const String fetchPhoneInfoMac = "/fetch_phone_info_mac";
  static const String categoryPage = "/categroy-page";
  static const String uploadPlaylist = "/upload-playlist";
  static const String videoPlayer = "/stream-player";
  static const String showSubsciptionPlan = "/show-subscription-plan";
  static const String paypalCheckoutScreen = "/paypal-checkout";
  static const String mobileDashboard = "/mobile-dashboard";

  // ── TV-only routes — additive, never reached from phone navigation ─────────
  static const String tvUploadPlaylist = "/tv-upload-playlist";
  static const String tvSubscriptionPlan = "/tv-subscription-plan";

  // static const String enterPhoneNumber = '/enterPhoneNumber';
  // static const String verifyPhoneOtp = '/verifyPhoneOtp';
  // static const String userForm = '/userForm';
  // static const String selectBank = '/select-bank';
  // static const String enterBankName = '/enter-bank-name';
  // static const String showBankAccountHolderDetailsForRegisterBank =
  //     '/bank-account-holder-details';
  // static const String mainDashobard = '/main-dashboard';
  // static const String scanResult = "/scan_result_page";

  // static const String scanQr = "/scanner_page";
  // static const String profilePage = "/profile_page";
}
