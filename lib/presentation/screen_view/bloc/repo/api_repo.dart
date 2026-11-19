import 'dart:convert';
import 'dart:developer';

import 'package:device_info_plus/device_info_plus.dart';

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:wiseplayertizen/core/error/exception.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/dio_client.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/get_playList_model.dart';

import '../../../../core/const/global_data/global_data.dart';
import '../model/channel_model.dart';
import '../model/payment _invoice_model.dart';
import '../model/videos_on_particuler_channel_model.dart';
import '../../../../data/models/fav.mode.dart';

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

  /// Step 1 of the lock flow:
  /// POST /api/playlist/{playlistId}/playlist-pin
  /// Body: { "pin": "1234", "confirmPin": "1234" }
  /// Sets (or replaces) the PIN hash on the server for this playlist.
  Future<void> setPlaylistPinOnServer({
    required String playlistId,
    required String pin,
  }) async {
    final res = await apiService.hitPostApi(
      endpoint: "/api/playlist/$playlistId/playlist-pin",
      reqData: {"pin": pin, "confirmPin": pin},
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? "Failed to set playlist PIN");
    }
  }

  /// Step 2 of the lock flow:
  /// POST /api/playlist/lock
  /// Body: { "playlistId": "...", "isLocked": true|false }
  /// Must be called AFTER [setPlaylistPinOnServer] when locking (isLocked=true).
  /// Setting isLocked=false also clears the pinHash from the playlist.
  Future<void> lockPlaylist({
    required String playlistId,
    required bool locked,
  }) async {
    final res = await apiService.hitPostApi(
      endpoint: "/api/playlist/lock",
      reqData: {"playlistId": playlistId, "isLocked": locked},
    );
    if (!res.isSuccess) {
      throw ServerException(
        res.error ?? "Failed to ${locked ? 'lock' : 'unlock'} playlist",
      );
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

  /// Verifies the PIN for a specific locked playlist.
  /// Hits POST /api/playlist/{playlistId}/verify-pin
  /// Body: {"pin": "1234"}
  /// On success (200 OK), returns the full [GetplayListModel] containing credentials (serverUrl, username, password).
  /// On failure (403 Forbidden / error), throws ServerException with error message.
  Future<GetplayListModel> verifyPlaylistPin({
    required String playlistId,
    required String pin,
  }) async {
    final res = await apiService.hitPostApi(
      endpoint: "/api/playlist/$playlistId/verify-pin",
      reqData: {"pin": pin},
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? "Incorrect PIN. Access denied.");
    }
    final responseData = res.data;
    if (responseData == null) {
      throw ServerException("Invalid response from server.");
    }

    Map<String, dynamic> playlistJson = {};
    if (responseData is Map<String, dynamic>) {
      if (responseData['success'] == false) {
        throw ServerException(
          responseData['message']?.toString() ??
              "Incorrect PIN. Access denied.",
        );
      }
      if (responseData['data'] != null &&
          responseData['data'] is Map<String, dynamic>) {
        playlistJson = responseData['data'] as Map<String, dynamic>;
      } else {
        playlistJson = responseData;
      }
    }
    return GetplayListModel.fromJson(playlistJson);
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

  /// Follows HTTP 302 redirects in Dart so we can keep our custom headers
  /// (especially `User-Agent: okhttp/4.12.0`) across cross-origin redirects.
  ///
  /// On iOS, AVPlayer strips all custom HTTP headers when it encounters a
  /// domain → IP redirect, reverting to `AppleCoreMedia/...`. Many IPTV CDNs
  /// then return 502. By resolving in Dart we own every hop.
  ///
  /// When [appendHlsSuffix] is `true` AND the final resolved URL does not
  /// already end in `.m3u8`, the path `/playlist.m3u8` is appended as an
  /// extra path segment. This makes AVFoundation (iOS) recognise the URL as
  /// an HLS manifest even when the real CDN URL is extension-less.
  Future<String> _resolveRedirect(
    String url, {
    bool appendHlsSuffix = false,
  }) async {
    String currentUrl = url;
    int redirectCount = 0;
    const maxRedirects = 8;

    while (redirectCount < maxRedirects) {
      HttpClient? client;
      try {
        final uri = Uri.tryParse(currentUrl);
        if (uri == null || !uri.hasScheme || !uri.scheme.startsWith('http')) {
          break;
        }

        client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        // Always send okhttp UA — IPTV servers validate this on every segment.
        request.headers.set('User-Agent', 'okhttp/4.12.0');
        request.headers.set(
          'Referer',
          '${uri.scheme}://${uri.host}${uri.hasPort ? ":${uri.port}" : ""}/',
        );

        final response = await request.close();
        final statusCode = response.statusCode;

        if (statusCode >= 300 && statusCode < 400) {
          final location = response.headers.value('location');
          await response.drain<void>().catchError((_) {});
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
        await response.drain<void>().catchError((_) {});
        break;
      } catch (e) {
        debugPrint("⚠️ [_resolveRedirect] Error resolving redirect: $e");
        break;
      } finally {
        client?.close(force: true);
      }
    }

    // iOS-only HLS suffix trick:
    // If the final CDN URL has no .m3u8 extension, AVPlayer won't recognise
    // it as an HLS manifest. Appending /playlist.m3u8 causes AVFoundation to
    // treat it as HLS while the server still returns the correct manifest
    // (Xtream/Nginx ignores the extra path segment in most setups).
    if (appendHlsSuffix) {
      final lower = currentUrl.toLowerCase().split('?').first;
      if (!lower.endsWith('.m3u8')) {
        // Strip any existing extension-less trailing component and add the
        // .m3u8 suffix so AVPlayer is happy.
        currentUrl = currentUrl.endsWith('/')
            ? '${currentUrl}playlist.m3u8'
            : '$currentUrl/playlist.m3u8';
        debugPrint(
          '📱 [_resolveRedirect] iOS HLS suffix appended: $currentUrl',
        );
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
    // MediaKit (FFmpeg) supports MKV, MP4, TS, and all containers natively on iOS.
    String? effectiveExtension = extension;

    String endpoint =
        "$urlTillPlayList&categoryId=$channelId&streamId=$streamId";

    if (effectiveExtension != null && effectiveExtension.isNotEmpty) {
      endpoint += "&containerExtension=$effectiveExtension";
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

    // ── Redirect resolution strategy ─────────────────────────────────────
    //
    // For media URLs with known extensions (.m3u8, .mp4, .mkv, .ts, etc.):
    // NEVER resolve redirects in Dart. IPTV servers enforce strict 1-connection
    // limits per user. Making an HTTP request in Dart opens a stream connection
    // that consumes the single available connection slot, causing native
    // AVPlayer / ExoPlayer to be rejected with:
    //   - HTTP 458: Max connections exceeded (on VOD)
    //   - HTTP 509: Bandwidth / stream limit exceeded (on Live)
    //
    // Native AVPlayer and ExoPlayer follow 302 redirects natively using the
    // headers passed in BetterPlayerDataSource.
    final String resolvedUrl;
    if (_hasKnownVideoExtension(url)) {
      debugPrint(
        "🎬 [getVideoUrl] Known video extension detected — skipping Dart redirect to preserve connection slot",
      );
      resolvedUrl = url;
    } else {
      debugPrint(
        "🎬 [getVideoUrl] Resolving redirects for extensionless URL: $url",
      );
      resolvedUrl = await _resolveRedirect(url);
    }

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

    await _savePdf(res.data, invoiceId);
  }

  Future<void> _savePdf(Uint8List bytes, String invoiceId) async {
    if (bytes.isEmpty) {
      debugPrint("❌ Bytes empty");
      return;
    }

    try {
      String filePath;

      if (Platform.isAndroid) {
        // App-private external dir — works on ALL Android versions,
        // NO permission required, Play Store safe.
        final dir = await getExternalStorageDirectory();
        final saveDir = dir ?? await getApplicationDocumentsDirectory();
        filePath = "${saveDir.path}/invoice_$invoiceId.pdf";
      } else {
        final dir = await getApplicationDocumentsDirectory();
        filePath = "${dir.path}/invoice_$invoiceId.pdf";
      }

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      debugPrint("✅ Saved at: $filePath");

      final result = await OpenFilex.open(filePath, type: "application/pdf");
      debugPrint("📂 Open result: ${result.type} — ${result.message}");
    } catch (e) {
      debugPrint("❌ Error: $e");
    }
  }

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    debugPrint("📱 SDK: $sdk");

    if (sdk >= 30) {
      if (await Permission.manageExternalStorage.isGranted) return true;
      final status = await Permission.manageExternalStorage.request();
      debugPrint("📋 manageExternalStorage: $status");
      return status.isGranted;
    } else {
      final status = await Permission.storage.request();
      debugPrint("📋 storage: $status");

      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }

      return false;
    }
  }

  // ── Favorites API ─────────────────────────────────────────────────────────

  /// POST /api/favorites — Add a favorite.
  Future<void> addFavorite({
    required String playlistId,
    required String streamId,
    required String streamType,
    String? name,
    String? streamIcon,
  }) async {
    final Map<String, dynamic> body = {
      'playlistId': playlistId,
      'streamId': streamId,
      'streamType': streamType, // "LIVE", "VOD", or "SERIES"
    };
    if (name != null && name.isNotEmpty) body['name'] = name;
    if (streamIcon != null && streamIcon.isNotEmpty)
      body['streamIcon'] = streamIcon;

    final res = await apiService.hitPostApi(
      endpoint: '/api/favorites',
      reqData: body,
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? 'Failed to add favorite');
    }
  }

  /// DELETE /api/favorites?playlistId=...&streamId=...&streamType=... — Remove a favorite.
  Future<void> removeFavorite({
    required String playlistId,
    required String streamId,
    required String streamType,
  }) async {
    print("fdsfsssssssssss");
    final queryParams =
        'playlistId=${Uri.encodeComponent(playlistId)}'
        '&streamId=${Uri.encodeComponent(streamId)}'
        '&streamType=${Uri.encodeComponent(streamType)}';
    final res = await apiService.hitDeleteApi(
      endpoint: '/api/favorites?$queryParams',
      reqData: null,
    );
    if (!res.isSuccess) {
      throw ServerException(res.error ?? 'Failed to remove favorite');
    }
  }

  /// GET /api/favorites/{playlistId} — Fetch all favorites for a playlist (optionally filtered by streamType).
  Future<List<FavModel>> getFavorites(
    String playlistId, {
    String? streamType,
  }) async {
    String endpoint = '/api/favorites/$playlistId';
    if (streamType != null && streamType.isNotEmpty) {
      endpoint += '?streamType=${Uri.encodeComponent(streamType)}';
    }

    final res = await apiService.hitGetApi(endpoint: endpoint);
    if (!res.isSuccess) {
      throw ServerException(res.error ?? 'Failed to load favorites');
    }

    dynamic rawData = res.data;
    if (rawData is String) {
      try {
        rawData = jsonDecode(rawData);
      } catch (_) {
        throw ServerException('Invalid favorites response format');
      }
    }

    if (rawData is List) {
      return rawData
          .whereType<Map<String, dynamic>>()
          .map((e) => FavModel.fromApiJson(e))
          .toList();
    }

    // Some APIs wrap in { "data": [...] }
    if (rawData is Map && rawData['data'] is List) {
      return (rawData['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => FavModel.fromApiJson(e))
          .toList();
    }

    return [];
  }

  /// GET /api/favorites/{playlistId}/play/{streamId}
  /// Query: streamType (required), extension (optional)
  /// Returns the direct playback URL for a favorite stream.
  Future<String> getFavoritePlayUrl({
    required String playlistId,
    required String streamId,
    required String streamType,
    String? extension,
  }) async {
    String endpoint =
        '/api/favorites/$playlistId/play/$streamId?streamType=${Uri.encodeComponent(streamType)}';
    if (extension != null && extension.isNotEmpty) {
      endpoint += '&extension=${Uri.encodeComponent(extension)}';
    }

    debugPrint("🎬 [getFavoritePlayUrl] Requesting endpoint: $endpoint");
    final res = await apiService.hitGetApi(endpoint: endpoint);
    if (!res.isSuccess) {
      throw ServerException(res.error ?? 'Failed to get favorite play URL');
    }

    dynamic rawData = res.data;
    debugPrint("📦 [getFavoritePlayUrl] Response: $rawData");

    if (rawData is String) {
      try {
        rawData = jsonDecode(rawData);
      } catch (_) {
        if (rawData.isNotEmpty) return rawData;
        throw ServerException('Invalid play URL response');
      }
    }
    if (rawData is Map) {
      final url = rawData['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        debugPrint("🎬 [getFavoritePlayUrl] Final URL: $url");
        return url;
      }
    }
    throw ServerException('No URL returned from play endpoint');
  }
}
