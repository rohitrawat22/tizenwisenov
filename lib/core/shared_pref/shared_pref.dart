import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
class SharedPref {
  static const _secureStorage = FlutterSecureStorage();

  static Future<String?> setUserDeviceInfo({
    required String macAddress,
    required String deviceId,
    required String status,
    required String token,
    required String deviceSecret,
  }) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    pref.setString('mac', macAddress);
    pref.setString('status', status);
    
    await _secureStorage.write(key: 'deviceId', value: deviceId);
    await _secureStorage.write(key: 'token', value: token); // SECURE
    await _secureStorage.write(key: 'deviceSecret', value: deviceSecret);
    return null;
  }

  static Future<Map<String, dynamic>> getUserDeviceInfo() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    String secureToken = await _secureStorage.read(key: 'token') ?? '';
    String secureDeviceId = await _secureStorage.read(key: 'deviceId') ?? '';
    String secureDeviceSecret = await _secureStorage.read(key: 'deviceSecret') ?? '';
    
    Map<String, String> userinfo = {
      'deviceId': secureDeviceId,
      'mac': pref.getString('mac') ?? '',
      'status': pref.getString('status') ?? '',
      'token': secureToken, // SECURE
      'deviceSecret': secureDeviceSecret,
    };
    return userinfo;
  }

  static Future<bool> getUserDeviceStatus() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    String status = pref.getString('status') ?? "";
    if (status == "ACTIVE") {
      return true;
    } else {
      return false;
    }
    // if (status == "INACTIVE" || status.isEmpty || status == "") {
    //   return false;
    // }
    // else{
    //   return false;
    // }
  }

  static setUserDeviceStatus(String status) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    pref.setString('status', status.toUpperCase());
  }

  static setRefershToken(String refershToken) async {
    await _secureStorage.write(key: 'token', value: refershToken);
  }

  static setValidateStatus({
    required String deviceId,
    required String status,
    required String token,
    required bool isAllow,
    required String plan,
    String? deviceSecret,
  }) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    pref.setString('status', status);
    pref.setBool('isAllow', isAllow);
    pref.setString('plan', plan);

    await _secureStorage.write(key: 'deviceId', value: deviceId);
    await _secureStorage.write(key: 'token', value: token); // SECURE
    if (deviceSecret != null) {
      await _secureStorage.write(key: 'deviceSecret', value: deviceSecret);
    }
  }

  static setLanguage({required String languageWord}) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    pref.setString('locale', languageWord);

    // if(locale==null){
    //   pref.setString('locale', 'en');
    // }else{
    //   pref.setString('locale', languageWord);
    // }
  }

  static Future<String> getLanguage() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    String locale = pref.getString('locale') ?? 'en';
    return locale;
  }

  static clear() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    pref.clear();
    await _secureStorage.deleteAll();
  }

}
