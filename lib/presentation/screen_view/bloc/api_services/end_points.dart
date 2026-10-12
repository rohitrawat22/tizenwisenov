//const String baseUrl = "https://caution-frozen-conjure.ngrok-free.dev";
const String baseUrl = "https://api.wise-player.com";

class Endpoints {
  static const String deviceRegister = "/api/device/register";
  static const String checkDeviceStatus = "/api/device/validate";
  static const String subscriptionStatus = "/api/subscription/status";
  static const String generateDeviceKeyEndpoint = "/api/device/key";
  static const String activateAccount = "/api/device/activate";
  static const String refershToken = "/api/device/refresh";
  
  // Device PIN
  static const String devicePin = "/api/device/pin";

  // Checkout endpoints (Placeholders)
  static const String initiateCheckout = "/api/checkout/initiate";
  static const String checkPaymentStatus = "/api/checkout/status";
}
