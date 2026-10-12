import 'dart:developer';
import 'dart:ui' as ui;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wiseplayertizen/core/utils/loader.dart';
import 'package:wiseplayertizen/core/utils/message_dialog.dart';
import 'package:wiseplayertizen/core/utils/snackbar.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';
import 'package:wiseplayertizen/core/widgets/cached_image.dart';
import 'package:wiseplayertizen/data/models/fav.mode.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/data/local_storage/hive_service.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/core/widgets/change_video_dialog.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';

class FavVideoPlayerScreen extends StatefulWidget {
  final FavModel favItem;
  static const String routeName = '/fav-video-player';

  const FavVideoPlayerScreen({super.key, required this.favItem});

  @override
  State<FavVideoPlayerScreen> createState() => _FavVideoPlayerScreenState();
}

class _FavVideoPlayerScreenState extends State<FavVideoPlayerScreen> {
  BetterPlayerController? _controller;
  bool _isPlayerReady = false;
  bool _isLoaderShowing = false;
  bool _isLive = false; // detect live or movie
  List<FavModel> favList = [];
  FavModel? _currentPlayingFav; // currently playing fav item

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentPlayingFav = widget.favItem;
    _loadFavList();
    log('🎬 ================= PLAYER STATE =================');
    log('▶️ _isPlayerReady     : $_isPlayerReady');
    log('⏳ _isLoaderShowing   : $_isLoaderShowing');
    log('📡 _isLive            : $_isLive');
    log('⭐ favList count      : ${favList.length}');
    log('🎯 _currentPlayingFav : ${_currentPlayingFav?.toJson()}');

    log('📦 ================= FAV LIST FULL DATA =================');
    for (int i = 0; i < favList.length; i++) {
      log('⭐ Fav [$i] : ${favList[i].toJson()}');
    }

    log('========================================================');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Reset pehle
      BlocProvider.of<WiseBloc>(context).add(ResetVideoUrlEvent());

      // Phir URL fetch karo
      _fetchVideoUrl(widget.favItem);
    });
  }

  @override
  void dispose() {
    final size =
        ui.PlatformDispatcher.instance.views.first.physicalSize /
        ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    final isTV = size.width > 800;

    if (!isTV) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }

    final old = _controller;
    _controller = null;
    _isPlayerReady = false;
    old?.dispose();
    super.dispose();
  }

  // ── Fetch URL from BLoC ──────────────────────────────────────────────────────

  void _fetchVideoUrl(FavModel fav) {
    if (!mounted) return;
    log("FavVideoPlayerScreen: fetching url for id => ${fav.id}");

    // FavModel ke andar isLive store karo ya id se detect karo
    // Yahan hum fav.url se detect karte hain
    // Agar url already hai toh direct play karo
    if (fav.url.isNotEmpty) {
      log("Direct URL found: ${fav.url}");
      _isLive = fav.url.contains('/live/');
      _initPlayer(fav.url, isLive: _isLive);
      return;
    }

    // URL nahi hai toh BLoC se fetch karo
    BlocProvider.of<WiseBloc>(context).add(
      GetVideoUrlEvent(
        channelId: fav.categoryId ?? "", // FavModel mein categoryId add karo
        streamId: fav.id,
        urlTillChannel: fav.urlTillChannel ?? "", // FavModel mein add karo
        extension: fav.containerExtension,
      ),
    );
  }

  // ── Player ───────────────────────────────────────────────────────────────────

  void _resetPlayer() {
    if (_controller != null) {
      final old = _controller;
      _controller = null;
      _isPlayerReady = false;
      old!.dispose();
    }
  }

  void _initPlayer(String url, {bool isLive = false}) {
    if (!mounted) return;
    log("FavVideoPlayerScreen: playing => $url | isLive: $isLive");

    _resetPlayer();

    BetterPlayerVideoFormat videoFormat = BetterPlayerVideoFormat.other;
    if (url.toLowerCase().contains('.m3u8')) {
      videoFormat = BetterPlayerVideoFormat.hls;
    }

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      headers: {"User-Agent": "okhttp/3.12.1"},
      liveStream: isLive,
      videoFormat: videoFormat,
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 10000,
        maxBufferMs: 60000,
        bufferForPlaybackMs: 2000,
        bufferForPlaybackAfterRebufferMs: 3000,
      ),
    );

    _controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoDetectFullscreenDeviceOrientation: false,
        fullScreenByDefault: false,
        allowedScreenSleep: false,
        errorBuilder: (context, errorMessage) {
          return const Center(
            child: Text(
              "Stream is currently unavailable or offline.",
              style: TextStyle(color: Colors.white),
            ),
          );
        },
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableSubtitles: true,
          enableAudioTracks: true,
          loadingColor: AppColor.accentRed,
          progressBarPlayedColor: AppColor.accentRed,
          progressBarHandleColor: AppColor.accentRed,
          progressBarBufferedColor: Colors.white24,
          controlBarColor: Colors.black87,
          liveTextColor: AppColor.accentRed,
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    if (mounted) {
      _isPlayerReady = true;
      setState(() {});
    }
  }

  // ── Loader ───────────────────────────────────────────────────────────────────

  void _showLoader() {
    if (!mounted || _isLoaderShowing) return;
    _isLoaderShowing = true;
    loader(context);
  }

  void _stopLoader() {
    if (!mounted || !_isLoaderShowing) return;
    _isLoaderShowing = false;
    stopLoaderWithoutRoot(context);
  }

  // ── Favourites ───────────────────────────────────────────────────────────────

  Future<void> _loadFavList() async {
    final data = HiveService.getFavList();
    if (mounted) setState(() => favList = data);
  }

  bool _isFav(String id) => favList.any((f) => f.id == id);

  Future<void> _toggleFav(FavModel fav) async {
    if (_isFav(fav.id)) {
      await HiveService.deleteFav(fav.id);
      if (mounted) {
        snackBar(context, '${fav.title} removed from favourites', Colors.red);
      }
    } else {
      await HiveService.addFav(fav);
      if (mounted) {
        snackBar(context, '${fav.title} added to favourites', Colors.green);
      }
    }
    await _loadFavList();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  Future<bool> _showChangeVideoDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      barrierDismissible: false,
      builder: (dialogCtx) => ChangeVideoDialog(
        streamName: _currentPlayingFav?.title ?? 'this stream',
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldLeave = await _showChangeVideoDialog();
        if (shouldLeave && mounted) {
          _controller?.pause();
          _stopLoader();
          BlocProvider.of<WiseBloc>(context).add(ResetVideoUrlEvent());
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),

        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F1A),
          iconTheme: const IconThemeData(color: Colors.white),
          leading: InkWell(
            onTap: () {
              _controller?.pause();
              _stopLoader();
              BlocProvider.of<WiseBloc>(context).add(ResetVideoUrlEvent());
              Navigator.pop(context);
            },
            child: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          title: CText(
            _currentPlayingFav?.title ?? widget.favItem.title,
            fontSize: 15,
            maxLines: 1,
          ),
          actions: [
            IconButton(
              onPressed: () => _toggleFav(_currentPlayingFav ?? widget.favItem),
              icon: Icon(
                _isFav(_currentPlayingFav?.id ?? widget.favItem.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: _isFav(_currentPlayingFav?.id ?? widget.favItem.id)
                    ? Colors.red
                    : Colors.white,
              ),
            ),
          ],
        ),

        // ── BlocConsumer ──────────────────────────────────────────────────────
        body: BlocConsumer<WiseBloc, WiseState>(
          listener: (context, state) {
            if (!mounted) return;
            log("FavVideoPlayerScreen listener: ${state.status}");

            if (state.status == Status.loading) {
              _showLoader();
            } else if (state.status == Status.error) {
              _stopLoader();
              messageDialog(
                title: const Text("Error"),
                content: Text(state.errorMessage),
                context: context,
                onTap: () {
                  if (mounted) Navigator.pop(context);
                },
                okk: "ok",
              );
            } else if (state.status == Status.littleError) {
              _stopLoader();
              snackBar(context, state.errorMessage, Colors.red);
            } else if (state.status == Status.success) {
              if (state.videoUrl.isNotEmpty && state.isVideoLoaded) {
                _stopLoader();
                log("FavVideoPlayerScreen: URL received => ${state.videoUrl}");

                _isLive = state.videoUrl.contains('/live/');
                _initPlayer(state.videoUrl, isLive: _isLive);
              } else if (state.isStopLoader) {
                _stopLoader();
              } else {
                _stopLoader();
              }
            }
          },

          buildWhen: (previous, current) =>
              previous.status != current.status ||
              previous.videoUrl != current.videoUrl,

          builder: (context, state) {
            return Column(
              children: [
                // ── Video Player ────────────────────────────
                if (_isPlayerReady && _controller != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: BetterPlayer(controller: _controller!),
                  )
                else
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      ),
                    ),
                  ),

                const SizedBox(height: 6),

                // ── Current Video Info ──────────────────────
                Container(
                  color: const Color(0xFF1C1C2E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedImage(
                          imageUrl:
                              _currentPlayingFav?.photoImage ??
                              widget.favItem.photoImage,
                          width: 70,
                          height: 46,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CText(
                              _currentPlayingFav?.title ?? widget.favItem.title,
                              fontSize: 14,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 3),
                            CText(
                              "ID: ${_currentPlayingFav?.id ?? widget.favItem.id}",
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ],
                        ),
                      ),
                      // Live / Movie badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _isLive ? Colors.red : Colors.blueGrey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CText(_isLive ? "LIVE" : "MOVIE", fontSize: 11),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // ── Favourites List Header ──────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: const [
                      Icon(Icons.favorite, color: Colors.red, size: 18),
                      SizedBox(width: 6),
                      CText("Favourites", fontSize: 14, color: Colors.white54),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // ── Favourites List ─────────────────────────
                Expanded(
                  child: favList.isEmpty
                      ? const Center(
                          child: CText(
                            "No favourites yet",
                            color: Colors.white30,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: favList.length,
                          itemBuilder: (context, index) {
                            final item = favList[index];
                            final isPlaying = item.id == _currentPlayingFav?.id;

                            return Card(
                              color: isPlaying
                                  ? const Color(0xFF72243A)
                                  : const Color(0xFF1C1C2E),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  if (isPlaying) return;

                                  setState(() {
                                    _currentPlayingFav = item;
                                  });

                                  // Reset + fetch new URL
                                  BlocProvider.of<WiseBloc>(context)
                                      .add(ResetVideoUrlEvent());

                                  _fetchVideoUrl(item);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    children: [
                                      // Thumbnail
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: CachedImage(
                                          imageUrl: item.photoImage,
                                          width: 90,
                                          height: 58,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 10),

                                      // Title + ID
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CText(
                                              item.title,
                                              fontSize: 13,
                                              maxLines: 2,
                                            ),
                                            const SizedBox(height: 3),
                                            CText(
                                              item.id,
                                              fontSize: 11,
                                              color: Colors.white30,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Playing icon OR remove button
                                      if (isPlaying)
                                        const Icon(
                                          Icons.equalizer,
                                          color: Colors.redAccent,
                                          size: 22,
                                        )
                                      else
                                        IconButton(
                                          onPressed: () => _toggleFav(item),
                                          icon: const Icon(
                                            Icons.favorite,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
