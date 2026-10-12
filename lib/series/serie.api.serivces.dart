// lib/presentation/screen_view/bloc/api_services/series_api_service.dart

import 'package:dio/dio.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/dio_client.dart';
import 'package:wiseplayertizen/series/series.model.dart';

class SeriesApiException implements Exception {
  final String message;
  SeriesApiException(this.message);
  @override
  String toString() => message;
}

class SeriesApiService {
  final Dio _dio = DioClient().dio;

  /// GET /api/series?playlistId=X&categoryId=Y
  Future<List<SeriesListModel>> getSeriesByCategory({
    required String playlistId,
    required String categoryId,
  }) async {
    // print("getSeriesDetail");
    try {
      final headers = await _buildHeaders();

      final response = await _dio.get(
        '/api/series',
        queryParameters: {'playlistId': playlistId, 'categoryId': categoryId},
        options: Options(headers: headers),
      );

      final data = response.data;
      if (data is List) {
        return SeriesListModel.listFromJson(data);
      }
      if (data is Map<String, dynamic> && data['data'] is List) {
        return SeriesListModel.listFromJson(data['data'] as List);
      }
      return const [];
    } on DioException catch (e) {
      throw SeriesApiException(_dioErrorMessage(e));
    } catch (e) {
      throw SeriesApiException('Unexpected error: $e');
    }
  }

  /// GET /api/series?playlistId=X&seriesId=Y
  Future<SeriesDetailModel> getSeriesDetail({
    required String playlistId,
    required String seriesId,
  }) async {
    // print("getSeriesDetail");
    try {
      final headers = await _buildHeaders();

      final response = await _dio.get(
        '/api/series',
        queryParameters: {'playlistId': playlistId, 'seriesId': seriesId},
        options: Options(headers: headers),
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return SeriesDetailModel.fromJson(data);
      }
      throw SeriesApiException('Unexpected response format for series detail');
    } on DioException catch (e) {
      throw SeriesApiException(_dioErrorMessage(e));
    } catch (e) {
      throw SeriesApiException('Unexpected error: $e');
    }
  }

  /// GET /api/series/play?playlistId=X&episodeId=Y&containerExtension=mkv
  ///
  /// Returns the final playable video URL for an episode. Backend may
  /// respond in one of two shapes — this handles both safely:
  ///  1. Raw string body: "https://cdn.example.com/.../555001.mkv"
  ///  2. JSON object: { "url": "..." } or { "videoUrl": "..." } or
  ///     { "data": { "url": "..." } }
  Future<(String url, int resumeSeconds)> getEpisodeUrl({
    required String playlistId,
    required String episodeId,
    required String containerExtension,
  }) async {
    try {
      final headers = await _buildHeaders();

      // Log request headers
      // print('--- Request Headers ---');
      // headers.forEach((key, value) => print('$key: $value'));

      final response = await _dio.get(
        '/api/series/play',
        queryParameters: {
          'playlistId': playlistId,
          'episodeId': episodeId,
          'containerExtension': containerExtension,
        },
        options: Options(headers: headers),
      );

      final data = response.data;

      // Log full response info
      // print('--- Response Status ---');
      // print(response.statusCode);
      // print('--- Response Headers ---');
      // response.headers.forEach((key, values) => print('$key: $values'));
      // print('--- Response Data (${data.runtimeType}) ---');
      // print(data);

      // Case 1: backend returns the URL as a raw string body (no resume info available).
      if (data is String && data.trim().isNotEmpty) {
        return (data.trim(), 0);
      }

      // Case 2: backend returns a JSON object with the URL + watch_progress nested inside.
      if (data is Map<String, dynamic>) {
        int resumeSeconds = 0;
        final url = _extractUrlFromMap(data);
        if (data['watch_progress'] != null) {
          resumeSeconds = _extractResumeSeconds(data);
        }

        if (url != null && url.isNotEmpty) {
          return (url, resumeSeconds);
        }
      }

      throw SeriesApiException('Video URL not found in server response.');
    } on DioException catch (e) {
      // print('--- DioException ---');
      // print('Request headers: ${e.requestOptions.headers}');
      // print('Response data: ${e.response?.data}');
      // print('Response headers: ${e.response?.headers}');
      throw SeriesApiException(_dioErrorMessage(e));
    } catch (e) {
      if (e is SeriesApiException) rethrow;
      throw SeriesApiException('Unexpected error: $e');
    }
  }

  int _extractResumeSeconds(Map<String, dynamic> data) {
    final progress = data['watch_progress'] ?? 0;
    if (progress is Map<String, dynamic>) {
      final resume = progress['resume_position_seconds'] ?? 0;
      if (resume is int) return resume;
      if (resume is double) return resume.toInt();
      if (resume is String) return int.tryParse(resume) ?? 0;
    }
    return 0;
  }

  /// Tries common key names ('url', 'videoUrl', 'stream_url', 'link'),
  /// including one level of nesting under 'data', so we don't break if
  /// the backend response shape changes slightly.
  String? _extractUrlFromMap(Map<String, dynamic> json) {
    for (final key in ['url', 'videoUrl', 'video_url', 'stream_url', 'link']) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      return _extractUrlFromMap(nested);
    }
    return null;
  }

  /// Builds X-Device-Token / X-Device-Fingerprint headers, matching the
  /// same pattern used in DioClient.hitPostApiCureent(). Reads deviceSecret
  /// from SharedPref for freshness, token/macAddress from global vars.
  Future<Map<String, dynamic>> _buildHeaders() async {
    final data = await SharedPref.getUserDeviceInfo();
    // print("dsfsdfsdf$data");
    return {
      if (token.isNotEmpty) 'X-Device-Token': token,
      if (macAddress.isNotEmpty) 'X-Device-Fingerprint': macAddress,
      if (data['deviceSecret'] != null) 'X-Device-Secret': data['deviceSecret'],
    };
  }

  String _dioErrorMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Check your internet.';
    }
    if (e.response != null) {
      final msg = e.response?.data is Map ? e.response?.data['message'] : null;
      return msg?.toString() ?? 'Server error (${e.response?.statusCode}).';
    }
    return e.message ?? 'Network error.';
  }

  Future<bool> postWatchProgress({
    required String streamId,
    required String playlistId,
    required String streamType, // "VOD" or "SERIES"
    required int positionSeconds,
    required int durationSeconds,
  }) async {
    // print("postWatchProgress");
    if (streamType != 'VOD' && streamType != 'SERIES') {
      throw SeriesApiException(
        'Invalid streamType "$streamType". Must be "VOD" or "SERIES".',
      );
    }

    try {
      final headers = await _buildHeaders();

      final body = {
        'streamId': streamId,
        'streamType': streamType,
        'playlistId': playlistId,
        'positionSeconds': positionSeconds,
        'durationSeconds': durationSeconds,
      };

      // print('--- Post Progress Request Body ---');
      // print(jsonEncode(body));

      final response = await _dio.post(
        '/api/progress',
        data: body,
        options: Options(headers: headers),
      );

      // print('--- Post Progress Response Status ---');
      // print(response.statusCode);
      // print(
      //   '--- Post Progress Response Data (${response.data.runtimeType}) ---',
      // );
      // print(response.data);

      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return true;
      }

      throw SeriesApiException('Failed to post progress (status $status).');
    } on DioException catch (e) {
      // print('--- DioException (postWatchProgress) ---');
      // print('Request headers: ${e.requestOptions.headers}');
      // print('Response data: ${e.response?.data}');
      // print('Response headers: ${e.response?.headers}');
      throw SeriesApiException(_dioErrorMessage(e));
    } catch (e) {
      if (e is SeriesApiException) rethrow;
      throw SeriesApiException('Unexpected error: $e');
    }
  }
}
