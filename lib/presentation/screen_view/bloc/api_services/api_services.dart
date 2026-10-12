import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:wiseplayertizen/core/error/exception.dart';
import 'package:wiseplayertizen/core/error/success_fail_result.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/end_points.dart';

import 'dio_client.dart';

class ApiService {
  final Dio _dio = DioClient().dio;

  Future<ApiResult<Map<String, dynamic>>> loginWithMac(
    Map<String, dynamic> data,
  ) async {
    try {
      Response res = await _dio.post('/api/device/register', data: data);
      if (kDebugMode) debugPrint("Login Response: ${res.data}");
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiResult.success(res.data);
      } else {
        if (kDebugMode) debugPrint(res.data['message']);
        return ApiResult.failure(
          "Login failed with status code: ${res.statusCode}",
        );
      }
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  Future<ApiResult> hitPostApi({
    required reqData,
    required String endpoint,
  }) async {
    try {
      Response res = await _dio.post("$baseUrl$endpoint", data: reqData);

      if (kDebugMode) {
        debugPrint("Request Headers: ${_dio.options.headers}");
        debugPrint("Request Data: $reqData");
        debugPrint("Response Headers: ${res.headers.map}");
        debugPrint("Response Data: ${res.data}");
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiResult.success(res.data);
      } else {
        String errorMessage = res.data['message'];
        return ApiResult.failure(errorMessage, res.data);
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    }
  }

  Future<ApiResult> hitGetApi({required String endpoint}) async {
    try {
      Response res = await _dio.get("$baseUrl$endpoint");
      if (kDebugMode) {
        debugPrint(res.toString());
        debugPrint(res.statusCode.toString());
      }
      if (res.statusCode == 200 || res.statusCode == 201) {
        return ApiResult.success(res.data);
      } else {
        String errorMessage = res.data['message'];
        return ApiResult.failure(errorMessage, res.data);
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    }
  }

  Future<ApiResult> hitPutApi({
    required String endpoint,
    dynamic reqData,
  }) async {
    try {
      Response res = await _dio.put("$baseUrl$endpoint", data: reqData);
      if (kDebugMode) {
        debugPrint(res.toString());
        debugPrint(res.statusCode.toString());
      }
      if (res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204) {
        return ApiResult.success(res.data);
      } else {
        String errorMessage = res.data['message'];
        return ApiResult.failure(errorMessage, res.data);
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    }
  }

  Future<ApiResult> hitDeleteApi({
    required String endpoint,
    dynamic reqData,
  }) async {
    try {
      Response res = await _dio.delete("$baseUrl$endpoint", data: reqData);
      if (kDebugMode) {
        debugPrint(res.toString());
        debugPrint(res.statusCode.toString());
      }
      if (res.statusCode == 200 ||
          res.statusCode == 201 ||
          res.statusCode == 204) {
        return ApiResult.success(res.data);
      } else {
        String errorMessage = res.data['message'];
        return ApiResult.failure(errorMessage, res.data);
      }
    } on DioException catch (e) {
      return _handleDioException(e);
    }
  }

  /// Performs a GET that does NOT follow redirects and returns the target
  /// `Location` header. Used by catch-up/timeshift playback where the server
  /// answers with a 302 to the upstream provider stream URL.
  Future<String> getRedirectLocation({required String endpoint}) async {
    try {
      Response res = await _dio.get(
        "$baseUrl$endpoint",
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (res.statusCode != null &&
          res.statusCode! >= 300 &&
          res.statusCode! < 400) {
        final location = res.headers.value('location');
        if (location != null && location.isNotEmpty) {
          return location;
        }
      }

      // Fallback: some deployments may answer with JSON instead of a 302.
      final data = res.data;
      if (data is Map && data['url'] != null) {
        return data['url'].toString();
      }

      throw ServerException(
        'Catch-up stream unavailable (HTTP ${res.statusCode}).',
      );
    } on DioException catch (e) {
      throw ServerException(
        e.response?.data['message']?.toString() ??
            'Catch-up stream unavailable.',
      );
    }
  }

  // Helper method to deduplicate DioException handling
  ApiResult _handleDioException(DioException e) {
    String errorMessage = "";
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        errorMessage = "Connection timeout. Please try again.";
        break;
      case DioExceptionType.sendTimeout:
        errorMessage = "Request send timeout. Try again.";
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = "Server is taking too long to respond.";
        break;
      case DioExceptionType.badResponse:
        errorMessage =
            e.response?.data['message'].toString() ?? "Server error occurred";
        break;
      case DioExceptionType.cancel:
        errorMessage = "Request was cancelled";
        break;
      default:
        errorMessage = "Something went wrong";
    }

    return ApiResult.failure(
      e.response?.data['message'] ?? errorMessage,
      e.response?.data,
    );
  }
}
