import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/error/success_fail_result.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/end_points.dart';

import '../../../../main.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late Dio dio;
  factory DioClient() => _instance;
  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        // Changed to 30 seconds to accommodate slow backends/large playlists
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) =>
            status != null && status < 500 && status != 401,
      ),
    );
    // ── KEY FIX: offload JSON decoding to a background isolate. ────────────
    // Large category playlists (10k–100k channels) were being decoded on the
    // main thread, which caused the sidebar to freeze for several seconds.
    // BackgroundTransformer moves jsonDecode into a worker isolate so the UI
    // thread stays at 60 fps during the response parsing phase.
    dio.transformer = BackgroundTransformer();
    dio.interceptors.add(AppInterceptor());
  }

  Future<ApiResult> hitPostApiCureent({
    required reqData,
    required String endpoint,
  }) async {
    if (kDebugMode) log('hitPostApiCureent → $endpoint');
    Map<String, dynamic> data = await SharedPref.getUserDeviceInfo();
    try {
      Response res = await dio.get(
        endpoint,
        data: reqData,
        options: Options(
          headers: {
            if (token.isNotEmpty) 'X-Device-Token': token,
            if (macAddress.isNotEmpty) 'X-Device-Fingerprint': macAddress,
            if (deviceId.isNotEmpty) 'X-Device-Secret': data['deviceSecret'],
          },
        ),
      );

      if (kDebugMode) {
        log('━━━━━━━━ REQUEST DEBUG ━━━━━━━━');
        log('URL: ${res.requestOptions.uri}');
        log('Status: ${res.statusCode}');
        log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiResult.success(res.data);
      } else {
        return ApiResult.failure(res.data['message'], res.data);
      }
    } on DioException catch (e) {
      return ApiResult.failure(
        e.response?.data['message'] ?? 'Error',
        e.response?.data,
      );
    }
  }

  Future<ApiResult> hitGetApiBytes({required String endpoint}) async {
    try {
      Response res = await dio.get(
        endpoint,
        options: Options(responseType: ResponseType.bytes),
      );

      if (kDebugMode) {
        log('━━━━━━━━ PDF REQUEST DEBUG ━━━━━━━━');
        log('URL: ${res.requestOptions.uri}');
        log('Status: ${res.statusCode}');
        log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiResult.success(res.data);
      } else {
        return ApiResult.failure('Failed to fetch PDF', null);
      }
    } on DioException catch (e) {
      return ApiResult.failure(
        e.response?.data['message'] ?? 'Error',
        e.response?.data,
      );
    }
  }
}

class AppInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      options.headers.forEach((key, value) {
        // Never log auth tokens or secrets
        if (key.toLowerCase() != 'x-device-token' &&
            key.toLowerCase() != 'x-device-secret') {
          log('🔑 $key: $value');
        }
      });
      log('➡️ REQUEST: ${options.method} ${options.uri}');
    }

    final isActivateApi = options.uri.toString().contains(
      '/api/device/activate',
    );

    if (token.isNotEmpty && !isActivateApi) {
      options.headers['X-Device-Token'] = token;
    }

    if (macAddress.isNotEmpty && !isActivateApi) {
      options.headers['X-Device-Fingerprint'] = macAddress;
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      log('✅ RESPONSE [${response.statusCode}]');
      log('📡 URL: ${response.requestOptions.uri}');
      log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (kDebugMode) {
      log('❌ ERROR: ${err.message} | Status: ${err.response?.statusCode}');
    }

    final options = err.requestOptions;

    // Avoid infinite loops on retry
    if (options.extra['retry'] == true) {
      return handler.reject(err);
    }

    if (err.response?.statusCode == 401 &&
        !options.path.contains(Endpoints.refershToken)) {
      log('Token expired, attempting refresh...');
      final newToken = await _refreshToken();

      if (newToken != null) {
        options.headers['X-Device-Token'] = newToken;
        options.extra['retry'] = true;
        try {
          final cloneReq = await DioClient().dio.fetch(options);
          return handler.resolve(cloneReq);
        } catch (e) {
          return handler.reject(err);
        }
      } else {
        log('Refresh failed, logging out...');
        await SharedPref.clear();
        token = '';
        macAddress = '';
        // ✅ Safe navigation with null check
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Future.delayed(Duration.zero, () {
            GoRouter.of(context).go(AppRoutes.loginWithMac);
          });
        }
        return handler.reject(err);
      }
    }
    super.onError(err, handler);
  }
}

/// Reads credentials from SharedPref (not global vars) to ensure freshness.
Future<String?> _refreshToken() async {
  if (kDebugMode) log('🔄 [Refresh Token] Starting refresh token process...');

  final Map<String, dynamic> data = await SharedPref.getUserDeviceInfo();

  final deviceSecret = data['deviceSecret'];
  final deviceFingerprint = data['mac'];

  if (deviceSecret == null ||
      (deviceSecret as String).isEmpty ||
      deviceFingerprint == null ||
      (deviceFingerprint as String).isEmpty) {
    if (kDebugMode) {
      log('❌ [Refresh Token] Aborted: Missing deviceSecret or fingerprint');
    }
    return null; // ✅ Return actual null, not the string "null"
  }

  try {
    if (kDebugMode) {
      log(
        '🌐 [Refresh Token] Making API call to: $baseUrl${Endpoints.refershToken}',
      );
    }

    final refreshDio = Dio(
      BaseOptions(validateStatus: (status) => status != null && status == 200),
    );

    final response = await refreshDio.post(
      '$baseUrl${Endpoints.refershToken}',
      options: Options(
        headers: {
          'X-Device-Secret': deviceSecret,
          'X-Device-Fingerprint': deviceFingerprint,
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode == 200) {
      final String newToken = response.data['token'];
      if (kDebugMode) log('✅ [Refresh Token] New token received successfully');

      await SharedPref.setRefershToken(newToken);
      token = newToken;

      if (kDebugMode) log('💾 [Refresh Token] Token saved successfully');
      return newToken;
    } else {
      if (kDebugMode) {
        log(
          '⚠️ [Refresh Token] Unexpected status code: ${response.statusCode}',
        );
      }
      return null; // ✅ Return actual null, not the string "null"
    }
  } catch (e, stackTrace) {
    if (kDebugMode) {
      log('❌ [Refresh Token] Exception occurred: $e');
      log('   StackTrace: $stackTrace');
    }
    return null; // ✅ Return actual null, not the string "null"
  }
}
