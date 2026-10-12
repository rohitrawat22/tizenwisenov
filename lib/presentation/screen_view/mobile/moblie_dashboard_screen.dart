import 'dart:async';
import 'dart:developer';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';

import 'dart:ui' as ui;

import '../../../core/routes/routes_path.dart';
import '../../../core/utils/loader.dart';
import '../../../core/utils/message_dialog.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/custom_textFormFiled.dart';
import '../bloc/api_services/api_services.dart';
import '../bloc/model/videos_on_particuler_channel_model.dart';
import '../bloc/wise_bloc.dart';
import '../common/dashboard_sub_screen/channels.dart';
import 'show_playList_video_in_listview.dart';

class MoblieDashboardScreen extends StatefulWidget {
  static const String routeName = AppRoutes.mobileDashboard;
  final String playListId;
  final bool isLiveTv;
  final bool isMovies;
  final bool isSeries;
  final bool isRadio;

  const MoblieDashboardScreen({
    super.key,
    required this.playListId,
    required this.isLiveTv,
    required this.isMovies,
    required this.isSeries,
    required this.isRadio,
  });

  @override
  State<MoblieDashboardScreen> createState() => _MoblieDashboardScreenState();
}

class _MoblieDashboardScreenState extends State<MoblieDashboardScreen> {
  ApiService apiService = ApiService();
  String finalUrl = "";
  String address = "";
  TextEditingController searchCtrl = TextEditingController();
  TextEditingController searchVideoCtrl = TextEditingController();
  bool isSearchChannelOnTextField = true;
  bool isSearching = false;
  BetterPlayerController? _controller;
  bool _isPlayerReady = false;
  bool _isLoaderShowing = false;
  Timer? _debounce;

  final String _screenId = DateTime.now().millisecondsSinceEpoch.toString();
  String _currentVideoUrl = "";

  Future<String> getData() async {
    String finalurl = "";
    if (!mounted) return finalurl;

    WiseBloc bloc = BlocProvider.of<WiseBloc>(context);

    if (widget.isLiveTv) {
      finalurl = "/api/live?playlistId=${widget.playListId}";
      bloc.add(ChannelEvent(url: "/api/live?playlistId=${widget.playListId}"));
    } else if (widget.isMovies) {
      finalurl = "/api/movie?playlistId=${widget.playListId}";
      bloc.add(ChannelEvent(url: "/api/movie?playlistId=${widget.playListId}"));
    } else if (widget.isSeries) {
      finalurl = "/api/series?playlistId=${widget.playListId}";
      bloc.add(ChannelEvent(url: finalurl));
    } else {
      finalurl = "/api/live?playlistId=${widget.playListId}";
      bloc.add(ChannelEvent(url: "/api/live?playlistId=${widget.playListId}"));
    }

    finalUrl = finalurl;
    return finalurl;
  }

  void _showLoader() {
    if (!mounted) return;
    if (_isLoaderShowing) return;
    _isLoaderShowing = true;
    loader(context);
  }

  void _stopLoader() {
    if (!mounted) return;
    if (!_isLoaderShowing) return;
    _isLoaderShowing = false;
    stopLoaderWithoutRoot(context);
  }

  void _resetPlayer() {
    if (_controller != null) {
      final oldController = _controller;
      _controller = null;
      _isPlayerReady = false;
      _currentVideoUrl = "";
      oldController!.dispose();
    }
  }

  void _resetPlayerAndRebuild() {
    _resetPlayer();
    if (mounted) setState(() {});
  }

  void getVideoData({
    required String videoUrl,
    required VideosOnPerticulerChannelModel? videoInfo,
    bool isCatchUp = false,
  }) {
    if (!mounted) return;

    if (_currentVideoUrl == videoUrl && _isPlayerReady) {
      log("Same URL already playing, skipping: $videoUrl");
      return;
    }

    log("getVideoData called with url: $videoUrl");
    debugPrint("🎬 [Player] Initializing with URL: $videoUrl");
    debugPrint(
      "🎬 [Player] isLiveTv: ${widget.isLiveTv} | isMovies: ${widget.isMovies} | isSeries: ${widget.isSeries} | isCatchUp: $isCatchUp",
    );

    _resetPlayer();

    BetterPlayerVideoFormat videoFormat = BetterPlayerVideoFormat.other;
    if (videoUrl.toLowerCase().contains('.m3u8')) {
      videoFormat = BetterPlayerVideoFormat.hls;
    }

    final extMatch = RegExp(r'\.([a-zA-Z0-9]+)(?:[\?#]|$)')
        .firstMatch(videoUrl);
    final String? extension = extMatch != null ? extMatch.group(1) : null;

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      videoUrl,
      // HotPlayer-speed optimisation B: use the modern okhttp/4.9.0 User-Agent
      // that IPTV CDNs expect. The old 3.x agent is sometimes throttled or
      // rejected by certain providers.
      headers: {"User-Agent": "okhttp/4.9.0"},
      liveStream: widget.isLiveTv && !isCatchUp,
      videoFormat: videoFormat,
      videoExtension: extension,
      // HotPlayer-speed optimisation A: start playing after only 500 ms of
      // data is buffered instead of the default 2 s, for near-instant channel
      // switching. The native ExoPlayer DefaultLoadControl also has
      // setPrioritizeTimeOverSizeThresholds(true) set in BetterPlayer.kt.
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 1000, // keep at least 1 s in the buffer at all times
        maxBufferMs: 5000, // never buffer more than 5 s ahead (live-friendly)
        bufferForPlaybackMs: 500, // START PLAYING after just 0.5 s buffered!
        bufferForPlaybackAfterRebufferMs: 1000, // resume after 1 s on rebuffer
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
          String displayMessage = "Stream is currently unavailable or offline.";
          final errStr = errorMessage?.toString() ?? "";
          if (errStr.contains("ExoPlaybackException") ||
              errStr.contains("MediaCodec") ||
              errStr.contains("Unknown error -14") ||
              errStr.contains("decoder")) {
            displayMessage = "This device's hardware does not support decoding this video's high resolution or format (e.g., 4K HEVC).";
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                displayMessage,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
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
      _currentVideoUrl = videoUrl;
      _isPlayerReady = true;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    _isPlayerReady = false;
    _controller = null;
    _currentVideoUrl = "";

    // FIX: ResetVideoUrlEvent SYNCHRONOUSLY fire karo taaki
    // pehle build mein hi BLoC state saaf ho
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        BlocProvider.of<WiseBloc>(context).add(ResetVideoUrlEvent());
        // Player ko bhi yahan reset karo taaki UI update ho
        _resetPlayerAndRebuild();
      }
    });

    getData();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    final controllerToDispose = _controller;
    _controller = null;
    _isPlayerReady = false;
    _currentVideoUrl = "";

    controllerToDispose?.dispose();
    searchCtrl.dispose();
    searchVideoCtrl.dispose();
    _stopLoader();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && mounted) {
          _controller?.pause();
          _stopLoader();
          BlocProvider.of<WiseBloc>(context).add(ResetVideoUrlEvent());
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Slate 900
              Color(0xFF000000), // Black
              Color(0xFF1E1E2C), // Deep Indigo
            ],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.3),
            elevation: 0,
            flexibleSpace: ClipRRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
            leadingWidth: 90,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 10),
                InkWell(
                  onTap: () {
                    if (mounted) {
                      _controller?.pause();
                      _stopLoader();
                      BlocProvider.of<WiseBloc>(context)
                          .add(ResetVideoUrlEvent());
                    }
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.arrow_back_ios),
                ),
                Builder(
                  builder: (context) {
                    return IconButton(
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                        _controller?.pause();
                      },
                      icon: const Icon(Icons.menu),
                    );
                  },
                ),
              ],
            ),
            title: Text(
              context
                      .watch<WiseBloc>()
                      .state
                      .filterVideoOnParticulerChannelList
                      .isEmpty
                  ? ""
                  : context
                            .watch<WiseBloc>()
                            .state
                            .selectedChannel
                            ?.categoryName ??
                        "No Category",
            ),
            actions: [
              isSearching
                  ? SizedBox(
                      height: 45,
                      // Live read: never stale after rotation. Clamped so
                      // it never crowds the back/menu icons on narrow phones.
                      width: (MediaQuery.sizeOf(context).width * 0.65).clamp(
                        160.0,
                        300.0,
                      ),
                      child: CustomTextFormFiled(
                        isOnChanged: true,
                        onChanged: (newValue) {
                          if (_debounce?.isActive ?? false) _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              if (!mounted) return;
                              BlocProvider.of<WiseBloc>(context).add(
                                FilterVideosOnPerticulerChannelEvent(
                                  searchText: newValue,
                                  isSearchChannelOnTextField: false,
                                ),
                              );
                            },
                          );
                        },
                        controller: searchCtrl,
                        hintText: "Search Video...",
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 15),
                          child: SizedBox(
                            height: 30,
                            width: 40,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                if (!mounted) return;
                                setState(() {
                                  isSearching = false;
                                  searchCtrl.clear();
                                });
                                BlocProvider.of<WiseBloc>(context).add(
                                  FilterVideosOnPerticulerChannelEvent(
                                    searchText: "",
                                    isSearchChannelOnTextField: false,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      onPressed: () {
                        if (mounted) setState(() => isSearching = true);
                      },
                      icon: const Icon(Icons.search),
                    ),
            ],
          ),

          drawer: Drawer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextFormFiled(
                          isOnChanged: true,
                          onChanged: (newValue) {
                            if (_debounce?.isActive ?? false)
                              _debounce?.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                if (!mounted) return;
                                BlocProvider.of<WiseBloc>(context).add(
                                  FilterVideosOnPerticulerChannelEvent(
                                    searchText: newValue,
                                    isSearchChannelOnTextField: true,
                                  ),
                                );
                              },
                            );
                          },
                          controller: searchCtrl,
                          hintText: "Search Channels...",
                        ),
                      ),
                      const SizedBox(width: 5),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          searchCtrl.clear();
                          if (mounted) {
                            BlocProvider.of<WiseBloc>(context).add(
                              FilterVideosOnPerticulerChannelEvent(
                                searchText: "",
                                isSearchChannelOnTextField: true,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Expanded(child: Channels(urlTillChannel: finalUrl)),
                ],
              ),
            ),
          ),

          body: BlocConsumer<WiseBloc, WiseState>(
            listener: (context, state) {
              if (!mounted) return;

              if (state.status == Status.loading ||
                  state.isMoreVideoOnParticulerChannelListLoading) {
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
                  okk: "okk",
                );
              } else if (state.status == Status.littleError) {
                _stopLoader();
                snackBar(context, state.errorMessage, Colors.red);
              } else if (state.status == Status.success) {
                if (state.videoUrl.isNotEmpty && state.isVideoLoaded) {
                  _stopLoader();

                  if (state.selectedVideo?.categoryId.toString() ==
                          state.selectedChannel?.categoryId.toString() ||
                      _isPlayerReady == false) {
                    if (mounted) {
                      getVideoData(
                        videoUrl: state.videoUrl,
                        videoInfo: state.selectedVideo,
                        isCatchUp: state.isCatchUpPlayback,
                      );
                    }
                  }
                } else if (state.isStopLoader) {
                  _stopLoader();
                } else {
                  _stopLoader();
                }
              }
            },

            buildWhen: (previous, current) =>
                previous.filterVideoOnParticulerChannelList !=
                current.filterVideoOnParticulerChannelList,

            builder: (context, state) {
              return Column(
                mainAxisAlignment:
                    state.filterVideoOnParticulerChannelList.isEmpty &&
                        !isSearching
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  // FIX: _isPlayerReady ke saath BLoC isVideoLoaded bhi check karo
                  // Dono true hone chahiye tabhi player dikhe
                  if (_isPlayerReady &&
                      _controller != null &&
                      state.isVideoLoaded &&
                      state.videoUrl.isNotEmpty)
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: BetterPlayer(controller: _controller!),
                      ),
                    ),

                  const SizedBox(height: 5),

                  state.filterVideoOnParticulerChannelList.isEmpty &&
                          !isSearching
                      ? const Center(
                          child: CText("Select the channel to watch video"),
                        )
                      : Expanded(
                          child: ShowPlaylistVideoInListView(
                            urlTillChannel: finalUrl,
                            isMovies: widget.isMovies,
                            isSeries: widget.isSeries,
                            // HotPlayer-speed optimisation C: pass credentials
                            // context so live streams bypass the backend API.
                            playListId: widget.playListId,
                            isLiveTv: widget.isLiveTv,
                          ),
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
