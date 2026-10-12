import 'dart:convert';
import 'dart:developer';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:wiseplayertizen/core/error/exception.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/dio_client.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/get_playList_model.dart';

import 'dart:io';

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../core/const/global_data/global_data.dart';
import '../model/channel_model.dart';
import '../model/payment _invoice_model.dart';
import '../model/videos_on_particuler_channel_model.dart';

class _ParseListArgs<T> {
  final List data;
  final T Function(Map<String, dynamic>) fromJson;
  _ParseListArgs(this.data, this.fromJson);
}

List<T> _parseListInBackground<T>(_ParseListArgs<T> args) {
  return args.data
      .where((e) => e is Map<String, dynamic>)
      .map((e) => args.fromJson(e as Map<String, dynamic>))
      .toList();
}

class ApiRepo {
  final ApiService apiService;
  ApiRepo({required this.apiService});

  Future<List<T>> _getList<T>({
    required String endpoint,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final res = await apiService.hitGetApi(endpoint: endpoint);
    debugPrint(res.toString());
    debugPrint("😀😀😀😀_getList");
    if (!res.isSuccess) {
      throw ServerException(res.error ?? "Some Error Occured");
    }

    dynamic rawData = res.data;

    // If the response is a String (e.g. server returned raw text), try to decode it as JSON
    if (rawData is String) {
      try {
        rawData = jsonDecode(rawData);
      } catch (_) {
        throw ServerException(
          "Invalid response format: expected JSON list but got a String",
        );
      }
    }

    if (rawData is! List) {
      throw ServerException(
        "Invalid response format: expected a List but got ${rawData.runtimeType}",
      );
    }

    final List data = rawData;

    return await compute(
      _parseListInBackground<T>,
      _ParseListArgs<T>(data, fromJson),
    );
  }

  Future<List<GetplayListModel>> getPlaylist() {
    return _getList(
      endpoint: "/api/playlist?deviceId=$macAddress",
      fromJson: GetplayListModel.fromJson,
    );
  }

  Future<void> pinPlaylist(String playlistId) async {
    final res = await apiService.hitPutApi(
      endpoint: "/api/playlist/$playlistId/pin",
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? "Failed to pin playlist");
    }
  }

  Future<void> unpinPlaylist(String playlistId) async {
    final res = await apiService.hitDeleteApi(
      endpoint: "/api/playlist/$playlistId/pin",
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? "Failed to unpin playlist");
    }
  }

  Future<void> togglePlaylistLock(String playlistId, bool isLocked) async {
    final res = await apiService.hitPostApi(
      endpoint: "/api/playlist/lock",
      reqData: {"playlistId": playlistId, "isLocked": isLocked},
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? "Failed to toggle playlist lock");
    }
  }

  /// Sets or changes the device-level PIN on the server.
  Future<void> setDevicePin({
    required String newPin,
    required String confirmPin,
    String? oldPin,
  }) async {
    final Map<String, dynamic> body = {"pin": newPin, "confirmPin": confirmPin};
    if (oldPin != null && oldPin.isNotEmpty) {
      body["oldPin"] = oldPin;
    }

    final res = await apiService.hitPostApi(
      endpoint: "/api/playlist/pin",
      reqData: body,
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? "Failed to set device PIN");
    }
  }

  /// Verifies the device PIN on the server (handles lockout protection).
  Future<bool> verifyDevicePin(String pin) async {
    final res = await apiService.hitPostApi(
      endpoint: "/api/playlist/pin/verify",
      reqData: {"pin": pin},
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? "Incorrect PIN");
    }
    return true;
  }

  /// Removes the device PIN from the server.
  Future<void> removeDevicePin(String currentPin) async {
    final res = await apiService.hitDeleteApi(
      endpoint: "/api/playlist/pin",
      reqData: {"pin": currentPin},
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? "Failed to remove device PIN");
    }
  }

  Future<List<GetplayListModel>> getPinnedPlaylists() {
    return _getList(
      endpoint: "/api/playlist/pinned",
      fromJson: GetplayListModel.fromJson,
    );
  }

  Future<List<ChannelModel>> getChannels(String endpointUrl) {
    return _getList(endpoint: endpointUrl, fromJson: ChannelModel.fromJson);
  }

  Future<List<VideosOnPerticulerChannelModel>> getVideoOnPerticulerChannels({
    required String urlTillChannel,
    required String channelId,
  }) {
    debugPrint("😀😀😀😀getVideoOnPerticulerChannels in rep${urlTillChannel}o");
    String urlForVideo = "$urlTillChannel&categoryId=$channelId";
    log("url for video in bloc in channel event $urlForVideo");
    return _getList(
      endpoint: urlForVideo,
      // "/api/xtream/streams?playlistId=$playListId&categoryId=$channelId",
      fromJson: VideosOnPerticulerChannelModel.fromJson,
    );
  }

  Future<String> _resolveRedirect(String url) async {
    String currentUrl = url;
    int redirectCount = 0;
    const maxRedirects = 8;

    while (redirectCount < maxRedirects) {
      try {
        final uri = Uri.tryParse(currentUrl);
        if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
          break;
        }

        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 6);
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        request.headers.set('User-Agent', 'okhttp/3.12.1');
        request.headers.set(
          'Referer',
          '${uri.scheme}://${uri.host}${uri.hasPort ? ":${uri.port}" : ""}/',
        );

        final response = await request.close();
        final statusCode = response.statusCode;

        if (statusCode >= 300 && statusCode < 400) {
          final location = response.headers.value('location');
          if (location != null && location.isNotEmpty) {
            if (location.startsWith('/')) {
              currentUrl = uri.replace(path: location).toString();
            } else {
              currentUrl = location;
            }
            redirectCount++;
            continue;
          }
        }
        break;
      } catch (e) {
        debugPrint("⚠️ [_resolveRedirect] Error resolving redirect: $e");
        break;
      }
    }
    return currentUrl;
  }

  // Extensions that better_player_plus / ExoPlayer can detect automatically.
  // For these URLs we skip our own redirect resolution and let ExoPlayer follow
  // the 302 chain natively (with the correct User-Agent from BetterPlayerDataSource
  // headers). Pre-resolving strips the extension from the final CDN URL, which
  // causes BetterPlayer.buildMediaSource to throw IndexOutOfBoundsException.
  static const _kKnownVideoExts = {
    'mkv',
    'mp4',
    'm4v',
    'avi',
    'mov',
    'wmv',
    'flv',
    'webm',
    'ts',
    'm2ts',
    'm3u8',
  };

  /// Returns true if [url] ends with a known video file extension.
  bool _hasKnownVideoExtension(String url) {
    final lower = url.toLowerCase().split('?').first; // strip query string
    final ext = lower.split('.').last;
    return _kKnownVideoExts.contains(ext);
  }

  Future<(String url, int? resumeSeconds)> getVideoUrl({
    required String urlTillPlayList,
    required String channelId,
    required String streamId,
    String? extension,
  }) async {
    String endpoint =
        "$urlTillPlayList&categoryId=$channelId&streamId=$streamId";

    if (extension != null && extension.isNotEmpty) {
      endpoint += "&containerExtension=$extension";
    }

    debugPrint("🎬 [getVideoUrl] Requesting endpoint: $endpoint");

    final res = await apiService.hitGetApi(endpoint: endpoint);

    debugPrint("📦 [getVideoUrl] Response: ${res.data}");

    if (!res.isSuccess) {
      debugPrint("❌ [getVideoUrl] API failed: ${res.error}");
      throw ServerException(res.error ?? "Some Error Occured");
    }

    dynamic rawData = res.data;

    // If API returns String, decode it
    if (rawData is String) {
      try {
        rawData = jsonDecode(rawData);
      } catch (_) {
        debugPrint("❌ [getVideoUrl] Failed to decode response");
      }
    }

    if (rawData is! Map) {
      throw ServerException("Invalid video response");
    }

    final Map<dynamic, dynamic> data = rawData;

    // Get video URL
    final String url = (data['url'] ?? '').toString();

    if (url.isEmpty) {
      throw ServerException("Video URL not found");
    }

    debugPrint("🎬 [getVideoUrl] Raw video URL: $url");

    // Get watch progress
    int? resumeSeconds;

    final watchProgress = data['watch_progress'];

    if (watchProgress != null && watchProgress is Map) {
      final resumeValue = watchProgress['resume_position_seconds'];

      if (resumeValue != null) {
        resumeSeconds = int.tryParse(resumeValue.toString()) ?? 0;
      }

      debugPrint("⏩ [getVideoUrl] Resume seconds: $resumeSeconds");
    } else {
      debugPrint("ℹ️ [getVideoUrl] No watch progress found");
    }

    // Resolve redirect
    final resolvedUrl = await _resolveRedirect(url);

    debugPrint("🎬 [getVideoUrl] Final resolved video URL: $resolvedUrl");

    return (resolvedUrl, resumeSeconds);
  }

  Future<String> getTimeshiftUrl({
    required String urlTillPlayList,
    required String streamId,
    required String timestamp,
    int duration = 60,
    String extension = 'ts',
  }) async {
    final playlistId = _extractPlaylistId(urlTillPlayList);
    if (playlistId == null || playlistId.isEmpty) {
      throw ServerException(
        "Could not determine playlist for catch-up playback",
      );
    }

    final endpoint =
        "/api/v2/stream/timeshift?playlistId=$playlistId"
        "&channelId=$streamId"
        "&timestamp=${Uri.encodeQueryComponent(timestamp)}"
        "&duration=$duration"
        "&extension=$extension";

    debugPrint("🎬 [getTimeshiftUrl] Requesting endpoint: $endpoint");
    final url = await apiService.getRedirectLocation(endpoint: endpoint);
    debugPrint("🎬 [getTimeshiftUrl] Resolved catch-up URL: $url");
    return url;
  }

  /// Extracts the `playlistId` query value from a URL built like
  /// `/api/live?playlistId=xxxx`. Returns null when absent.
  String? _extractPlaylistId(String url) {
    final match = RegExp(r'[?&]playlistId=([^&]+)').firstMatch(url);
    return match?.group(1);
  }

  Future<bool> isValidPlayList({required playListId}) async {
    final res = await apiService.hitGetApi(
      endpoint: "/api/xtream/auth?playlistId=$playListId",
    );
    if (!res.isSuccess) {
      final message = res.data is Map
          ? (res.data['message'] ?? "Playlist verification failed")
          : "Playlist verification failed";
      throw ServerException(message);
    }
    return true;
  }

  Future<Map<String, dynamic>> openPaypall({
    required String isLimeTimePayment,
    required String endpoints,
  }) async {
    final res = await apiService.hitPostApi(
      endpoint: endpoints,
      reqData: {"deviceId": macAddress, "planName": isLimeTimePayment},
    );
    log(
      "this is response data of payment $macAddress and res is res $isLimeTimePayment ",
    );
    log("this is respons data of payment ${res.data}");
    if (!res.isSuccess) {
      throw (ServerException(res.data['message'] ?? "some error comes"));
    } else {
      return res.data;
    }
  }

  final DioClient _dioClient = DioClient();
  Future<PaymentInvoiceModel> getPlanInvoice({
    required String endpoints,
    dynamic data,
  }) async {
    debugPrint("😀😀😀😀");
    debugPrint(endpoints);

    final res = await _dioClient.hitPostApiCureent(
      endpoint: endpoints,
      reqData: data,
    );
    log("this is respons data of payment ${res.data}");

    if (!res.isSuccess) {
      String errMsg = "some error comes";
      if (res.data is Map && res.data['message'] != null) {
        errMsg = res.data['message'].toString();
      } else if (res.data is String && res.data.toString().isNotEmpty) {
        errMsg = res.data.toString();
      }
      throw ServerException(errMsg);
    } else {
      dynamic rawData = res.data;
      if (rawData is String) {
        if (rawData.trim().isEmpty) {
          return PaymentInvoiceModel.empty();
        }
        try {
          rawData = jsonDecode(rawData);
        } catch (_) {
          return PaymentInvoiceModel.empty();
        }
      }

      if (rawData is Map<String, dynamic>) {
        return PaymentInvoiceModel.fromJson(rawData);
      } else if (rawData is Map) {
        return PaymentInvoiceModel.fromJson(Map<String, dynamic>.from(rawData));
      } else {
        return PaymentInvoiceModel.empty();
      }
    }
  }

  Future<void> downloadInvoicePdf({
    required String invoiceId,
    required String deviceId,
  }) async {
    final res = await _dioClient.hitGetApiBytes(
      endpoint: "/api/payment/invoice/$invoiceId/pdf?deviceId=$deviceId",
    );

    if (!res.isSuccess) throw ServerException("PDF download failed");

    //await _savePdf(res.data, invoiceId);
  }
}
