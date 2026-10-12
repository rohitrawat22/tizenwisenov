import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_info_plus_tizen/device_info_plus_tizen.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// 📱 MAIN DEVICE INFO
// ---------------------------------------------------------------------------
Future<Map<String, String>> getDeviceInfo() async {
  debugPrint('🚀 ========== GET DEVICE INFO START ==========');

  try {
    if (kIsWeb) {
      debugPrint('🌐 Platform detected: WEB');
      final info = await _getWebInfo();
      debugPrint('✅ Web Device Info: $info');
      return info;
    }

    final platform = currentOperatingSystem();
    debugPrint('💻 Operating System: $platform');

    if (platform == 'linux') {
      debugPrint('📺 Samsung Tizen TV detected');
      final info = await _getTizenInfo();
      debugPrint('✅ Tizen Device Info: $info');
      return info;
    }

    if (platform == 'android') {
      debugPrint('🤖 Android device detected');
      final info = await _getAndroidInfo();
      debugPrint('✅ Android Device Info: $info');
      return info;
    }

    if (platform == 'ios') {
      debugPrint('🍎 iOS device detected');
      final info = await _getIosInfo();
      debugPrint('✅ iOS Device Info: $info');
      return info;
    }

    debugPrint('❌ Unsupported platform: $platform');
    throw UnsupportedError('Unsupported platform: $platform');
  } catch (e, stackTrace) {
    debugPrint('❌ GET DEVICE INFO ERROR: $e');
    debugPrint('📍 STACK TRACE: $stackTrace');
    rethrow;
  } finally {
    debugPrint('🏁 ========== GET DEVICE INFO END ==========');
  }
}

// ---------------------------------------------------------------------------
// 📺 TIZEN
// ---------------------------------------------------------------------------
Future<Map<String, String>> _getTizenInfo() async {
  debugPrint('📺 ========== TIZEN DEVICE INFO START ==========');

  log('📺 Platform is Tizen');

  final prefs = await SharedPreferences.getInstance();
  debugPrint('💾 SharedPreferences initialized');

  final tizenInfo = await DeviceInfoPluginTizen().tizenInfo;

  debugPrint('📋 Tizen Model Name: ${tizenInfo.modelName}');
  debugPrint('⚙️ Tizen Platform Version: ${tizenInfo.platformVersion}');

  final model = (tizenInfo.modelName ?? '').trim().isEmpty
      ? 'tizen'
      : tizenInfo.modelName!.trim();

  debugPrint('📺 Final Device Model: $model');

  String? id = prefs.getString('tizen_device_id');

  if (id == null || id.isEmpty) {
    debugPrint('🆕 No saved Tizen Device ID. Generating UUID...');

    id = const Uuid().v4();

    await prefs.setString('tizen_device_id', id);

    debugPrint('💾 New Tizen Device ID saved');
  } else {
    debugPrint('✅ Existing Tizen Device ID found');
  }

  debugPrint('🆔 Tizen Device ID: $id');

  final macId = generateMacLikeId(androidId: id, model: model);

  final result = <String, String>{
    "brand": "Samsung",
    "model": model,
    "device": "TV",
    "manufacturer": "Samsung",
    "androidVersion": tizenInfo.platformVersion ?? '',
    "plateform": "TIZEN",
    "macLikeId": macId,
  };

  debugPrint('📦 Final Tizen Information: $result');
  debugPrint('📺 ========== TIZEN DEVICE INFO END ==========');

  return result;
}

// ---------------------------------------------------------------------------
// 🤖 ANDROID
// ---------------------------------------------------------------------------
Future<Map<String, String>> _getAndroidInfo() async {
  debugPrint('🤖 ========== ANDROID DEVICE INFO START ==========');

  final deviceInfo = DeviceInfoPlugin();
  const storage = FlutterSecureStorage();

  final androidInfo = await deviceInfo.androidInfo;

  debugPrint('🏷️ Brand: ${androidInfo.brand}');
  debugPrint('📱 Model: ${androidInfo.model}');
  debugPrint('🔧 Device: ${androidInfo.device}');
  debugPrint('🏭 Manufacturer: ${androidInfo.manufacturer}');
  debugPrint('🆔 Android Hardware ID: ${androidInfo.id}');
  debugPrint('📲 Android Release: ${androidInfo.version.release}');
  debugPrint('⚙️ SDK Version: ${androidInfo.version.sdkInt}');

  String rawId = androidInfo.id.trim();

  if (rawId.isEmpty || rawId == 'unknown') {
    debugPrint('⚠️ Hardware ID unavailable. Checking secure storage...');

    String? stored = await storage.read(key: 'android_device_id');

    if (stored == null || stored.isEmpty) {
      debugPrint('🆕 Generating fallback Android UUID...');

      stored = const Uuid().v4();

      await storage.write(key: 'android_device_id', value: stored);

      debugPrint('💾 Fallback UUID saved');
    } else {
      debugPrint('✅ Existing fallback UUID found');
    }

    rawId = stored;
  }

  debugPrint('🆔 Final Android ID: $rawId');

  final macId = generateMacLikeId(androidId: rawId, model: androidInfo.model);

  final result = <String, String>{
    "brand": androidInfo.brand,
    "model": androidInfo.model,
    "device": androidInfo.device,
    "manufacturer": androidInfo.manufacturer,
    "androidVersion": androidInfo.version.release,
    "sdkInt": androidInfo.version.sdkInt.toString(),
    "androidId": rawId,
    "macLikeId": macId,
    "plateform": "ANDROID",
  };

  debugPrint('📦 Final Android Information: $result');
  debugPrint('🤖 ========== ANDROID DEVICE INFO END ==========');

  return result;
}

// ---------------------------------------------------------------------------
// 🍎 IOS
// ---------------------------------------------------------------------------
Future<Map<String, String>> _getIosInfo() async {
  debugPrint('🍎 ========== IOS DEVICE INFO START ==========');

  log('🍎 Platform is iOS');

  final deviceInfo = DeviceInfoPlugin();
  const storage = FlutterSecureStorage();

  final iosInfo = await deviceInfo.iosInfo;

  debugPrint('📱 Model: ${iosInfo.utsname.machine}');
  debugPrint('⚙️ System Version: ${iosInfo.systemVersion}');
  debugPrint('📲 Device Name: ${iosInfo.model}');

  String? deviceId = await storage.read(key: 'device_id');

  if (deviceId == null || deviceId.isEmpty) {
    debugPrint('🆕 Generating iOS Device ID...');

    deviceId = generateMacLikeId(
      androidId: DateTime.now().millisecondsSinceEpoch.toString(),
      model: iosInfo.utsname.machine,
    );

    await storage.write(key: 'device_id', value: deviceId);

    debugPrint('💾 iOS Device ID saved');
  } else {
    debugPrint('✅ Existing iOS Device ID found');
  }

  final result = <String, String>{
    "brand": "Apple",
    "model": iosInfo.utsname.machine,
    "device": iosInfo.model,
    "androidVersion": iosInfo.systemVersion,
    "plateform": "APPLE",
    "macLikeId": deviceId,
  };

  debugPrint('📦 Final iOS Information: $result');
  debugPrint('🍎 ========== IOS DEVICE INFO END ==========');

  return result;
}

// ---------------------------------------------------------------------------
// 🌐 WEB
// ---------------------------------------------------------------------------
Future<Map<String, String>> _getWebInfo() async {
  debugPrint('🌐 ========== WEB DEVICE INFO START ==========');

  log('🌐 Platform is Web');

  final prefs = await SharedPreferences.getInstance();
  final webInfo = await DeviceInfoPlugin().webBrowserInfo;

  final model = webInfo.userAgent ?? 'web';

  debugPrint('🌍 Browser: ${webInfo.browserName.name}');
  debugPrint('🏷️ Vendor: ${webInfo.vendor}');
  debugPrint('📱 User Agent: $model');
  debugPrint('⚙️ App Version: ${webInfo.appVersion}');

  String? id = prefs.getString('web_device_id');

  if (id == null || id.isEmpty) {
    debugPrint('🆕 Generating Web Device UUID...');

    id = const Uuid().v4();

    await prefs.setString('web_device_id', id);

    debugPrint('💾 Web Device UUID saved');
  } else {
    debugPrint('✅ Existing Web Device UUID found');
  }

  debugPrint('🆔 Web Device ID: $id');

  final result = <String, String>{
    "brand": webInfo.vendor ?? 'web',
    "model": webInfo.browserName.name,
    "device": "WEB",
    "androidVersion": webInfo.appVersion ?? '',
    "plateform": "WEB",
    "macLikeId": generateMacLikeId(androidId: id, model: model),
  };

  debugPrint('📦 Final Web Information: $result');
  debugPrint('🌐 ========== WEB DEVICE INFO END ==========');

  return result;
}

// ---------------------------------------------------------------------------
// 🔐 MAC-LIKE ID GENERATOR
// ---------------------------------------------------------------------------
String generateMacLikeId({required String androidId, required String model}) {
  debugPrint('🔐 ========== ID GENERATION START ==========');

  debugPrint('🆔 Input Device ID: $androidId');
  debugPrint('📱 Input Model: $model');

  final raw = '$androidId|$model';

  debugPrint('🧩 Combined Input: $raw');

  final bytes = utf8.encode(raw);
  final digest = sha256.convert(bytes).toString();

  debugPrint('🔏 SHA-256 Hash Generated');

  final mac = digest.substring(0, 12).toUpperCase();

  final macTypeAddress = mac
      .replaceAllMapped(RegExp(r'.{2}'), (match) => '${match.group(0)}:')
      .substring(0, 17);

  debugPrint('📡 Generated MAC-like ID: $macTypeAddress');
  debugPrint('🔐 ========== ID GENERATION END ==========');

  return macTypeAddress;
}

// ---------------------------------------------------------------------------
// 💻 CURRENT PLATFORM
// ---------------------------------------------------------------------------
String currentOperatingSystem() {
  final platform = Platform.operatingSystem;

  debugPrint('💻 Platform.operatingSystem: $platform');

  return platform;
}
