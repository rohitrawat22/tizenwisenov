import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/utils/breakpoints.dart';
import 'package:wiseplayertizen/core/utils/loader.dart';
import 'package:wiseplayertizen/core/utils/message_dialog.dart';
import 'package:wiseplayertizen/core/utils/snackbar.dart';
import 'package:wiseplayertizen/core/widgets/custom_textFormFiled.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/content_option_tv/content_option_tv.dart';
import 'package:wiseplayertizen/presentation/screen_view/web/screens/stream_player.dart';
import 'package:wiseplayertizen/core/widgets/geo_location_banner.dart';
import 'package:wiseplayertizen/series/serie.details.dart';

import '../../common/dashboard_sub_screen/channels.dart';
import '../../common/dashboard_sub_screen/show_playList_video.dart';

class WebDashboardScreen extends StatefulWidget {
  static const String routeName = AppRoutes.webDashboard;
  final String playListId;
  final bool isLiveTv;
  final bool isMovies;
  final bool isSeries;
  final bool isRadio;

  const WebDashboardScreen({
    super.key,
    required this.playListId,
    required this.isLiveTv,
    required this.isMovies,
    required this.isSeries,
    required this.isRadio,
  });

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  ApiService apiService = ApiService();
  String finalUrl = '';
  TextEditingController categorySearchCtrl = TextEditingController();
  TextEditingController streamSearchCtrl = TextEditingController();
  bool isSearchChannelOnTextField = true;
  List<EpgProgramModel>? programList = [];

  /// Guard to prevent double-push when video URL arrives while already navigating.
  bool _isNavigatingToPlayer = false;

  // No longer `late final` — it's set in didChangeDependencies(), not
  // initState(), so it can't be a single-assignment `late final` field
  // guaranteed to run before other reads.
  bool _isPhone = false;
  bool _isPhoneInitialized = false;

  @override
  void initState() {
    super.initState();
    // ❌ removed: _isPhone = isPhoneWidth(context);
    // MediaQuery.of(context) (which isPhoneWidth() calls under the hood)
    // is not safe to call in initState() — the element isn't fully
    // attached to the tree yet at this point.
    // rotateScreen() is also deferred (see below) since it depends on _isPhone.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isPhoneInitialized) {
      _isPhone = isPhoneWidth(context);
      _isPhoneInitialized = true;
      rotateScreen();
    }
  }

  Timer? _searchDebounceTimer;

  void _onSearchDebounced(String text, bool isCategory) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        BlocProvider.of<WiseBloc>(context).add(
          FilterVideosOnPerticulerChannelEvent(
            searchText: text,
            isSearchChannelOnTextField: isCategory,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    categorySearchCtrl.dispose();
    streamSearchCtrl.dispose();
    super.dispose();
  }

  void rotateScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // Device chahe phone ho, tablet ho ya TV-width ho — is screen pe
      // hamesha landscape lock rahega.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      finalUrl = await _buildFinalUrl();
      if (!mounted) return;
      setState(() {});
    });
  }

  void getProgramData({required String streaID, required String videoUrl}) {
    if (widget.isLiveTv) {
      // Immediately open the video player without waiting for EPG JSON
      _openVideoPlayer(videoUrl: videoUrl, streaID: streaID, resumeSecond: 0);
      // Fetch EPG non-blockingly in background
      // getChannelEpgPrograms(playlistId: widget.playListId, channelId: streaID)
      //     .then((epg) {
      //       if (mounted) {
      //         programList = epg;
      //       }
      //     })
      //     .catchError((e) {
      //       debugPrint("⚠️ EPG background fetch error: $e");
      //     });
    }
  }

  Future<String> _buildFinalUrl() async {
    if (!mounted) return '';
    final WiseBloc bloc = BlocProvider.of<WiseBloc>(context);
    String url = '';

    if (widget.isLiveTv) {
      url = '/api/live?playlistId=${widget.playListId}';
      bloc.add(ChannelEvent(url: url));
    } else if (widget.isMovies) {
      url = '/api/movie?playlistId=${widget.playListId}';
      bloc.add(ChannelEvent(url: url));
    } else if (widget.isSeries) {
      url = '/api/series?playlistId=${widget.playListId}';
      bloc.add(ChannelEvent(url: url));
    } else {
      url = '/api/live?playlistId=${widget.playListId}';
      bloc.add(ChannelEvent(url: url));
    }

    return url;
  }

  // ...rest of the class (build(), _navigateToPlayer(), etc.) is unchanged.
  Future<void> _navigateToPlayer(
    String videoUrl,
    String streaID,
    int resumeSecond,
  ) async {
    if (_isNavigatingToPlayer || !mounted) return;

    _isNavigatingToPlayer = true;

    try {
      // Stop loader if running
      if (isLoaderRunning) {
        stopLoaderWithoutRoot(context);
      }

      // Show resume dialog ONLY when saved progress is greater than 0
      if (resumeSecond > 0) {
        final result = await showResumeCancelDialog(context);

        if (!mounted) return;

        switch (result) {
          case ResumeDialogResult.resume:
            // Continue from saved position
            _openVideoPlayer(
              videoUrl: videoUrl,
              streaID: streaID,
              resumeSecond: resumeSecond,
            );
            break;

          case ResumeDialogResult.restart:
            // Start video from beginning
            _openVideoPlayer(
              videoUrl: videoUrl,
              streaID: streaID,
              resumeSecond: 0,
            );
            break;

          case ResumeDialogResult.cancel:
            // Don't navigate anywhere
            _isNavigatingToPlayer = false;
            break;
        }
      } else {
        // No saved progress → directly open player
        if (widget.isLiveTv) {
          getProgramData(streaID: streaID, videoUrl: videoUrl);
        } else {
          _openVideoPlayer(
            videoUrl: videoUrl,
            streaID: streaID,
            resumeSecond: 0,
          );
        }
      }
    } catch (e) {
      _isNavigatingToPlayer = false;

      debugPrint("❌ Error navigating to video player: $e");
    }
  }

  void _openVideoPlayer({
    required String videoUrl,
    required String streaID,
    required int resumeSecond,
  }) {
    if (!mounted) {
      _isNavigatingToPlayer = false;
      return;
    }

    final wiseBloc = BlocProvider.of<WiseBloc>(context);
    final wiseState = wiseBloc.state;

    final channels =
        (wiseState.filterVideoOnParticulerChannelList.isNotEmpty ||
            (wiseState.selectedChannel != null &&
                wiseState.selectedChannel!.categoryName == 'All'))
        ? wiseState.filterVideoOnParticulerChannelList
        : wiseState.videoOnParticulerChannelList;

    int initialIndex = channels.indexWhere(
      (c) => c.streamId?.toString() == streaID,
    );
    if (initialIndex < 0) initialIndex = 0;

    GoRouter.of(context).push(
      VideoPlayerScreen.routeName,
      extra: {
        "playlistId": widget.playListId,
        "streaID": streaID,
        "videoUrl": videoUrl,
        "resumeSecond": resumeSecond,
        "videoInfo": wiseState.selectedVideo,
        "isLiveTv": widget.isLiveTv,
        "programList": programList,
        "streamType": "VOD",
        "channelList": channels,
        "initialChannelIndex": initialIndex,
      },
    );

    // Reset immediately so if user comes back and clicks another stream,
    // it won't be stuck ignoring clicks forever.
    _isNavigatingToPlayer = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
            children: [
              TextSpan(
                text: "Wise ",
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: "Player",
                style: TextStyle(color: AppColor.accentRed),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.select)) {
                  if (!mounted) return KeyEventResult.ignored;
                  final newValue = !isSearchChannelOnTextField;
                  setState(() {
                    isSearchChannelOnTextField = newValue;
                    categorySearchCtrl.clear();
                    streamSearchCtrl.clear();
                  });
                  BlocProvider.of<WiseBloc>(context).add(
                    FilterVideosOnPerticulerChannelEvent(
                      searchText: '',
                      isSearchChannelOnTextField: newValue,
                    ),
                  );
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  return GestureDetector(
                    onTap: () {
                      if (!mounted) return;
                      final newValue = !isSearchChannelOnTextField;
                      setState(() {
                        isSearchChannelOnTextField = newValue;
                        categorySearchCtrl.clear();
                        streamSearchCtrl.clear();
                      });
                      BlocProvider.of<WiseBloc>(context).add(
                        FilterVideosOnPerticulerChannelEvent(
                          searchText: '',
                          isSearchChannelOnTextField: newValue,
                        ),
                      );
                    },
                    child: AnimatedScale(
                      scale: isFocused ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E28),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFocused
                                ? Colors.white
                                : Colors.white.withOpacity(0.1),
                            width: isFocused ? 2.5 : 1.0,
                          ),
                          boxShadow: isFocused
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.2),
                                    blurRadius: 10,
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.search_rounded,
                              color: Colors.white54,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            // Categories tab
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSearchChannelOnTextField
                                    ? AppColor.accentRed
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Categories',
                                style: TextStyle(
                                  color: isSearchChannelOnTextField
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Streams tab
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: !isSearchChannelOnTextField
                                    ? const Color(0xFF00BCD4)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Streams',
                                style: TextStyle(
                                  color: !isSearchChannelOnTextField
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: BlocListener<WiseBloc, WiseState>(
        listener: (context, state) {
          log('WebDashboard BlocListener status = ${state.status}');

          if (!mounted) return;

          if (state.status == Status.loading) {
            if (!isLoaderRunning) {
              loader(context);
              isLoaderRunning = true;
            }
          } else if (state.status == Status.error) {
            if (isLoaderRunning) stopLoaderWithoutRoot(context);

            messageDialog(
              title: const Text('Error'),
              content: Text(state.errorMessage),
              context: context,
              onTap: () {
                print("fdsdfsdfsd${Status.loading}");
                print("fdsdfsdfsd${Status}");
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CategoryPage()),
                );
              },
              okk: 'OK',
            );
          } else if (state.status == Status.littleError) {
            if (isLoaderRunning) stopLoaderWithoutRoot(context);
            snackBar(context, state.errorMessage, Colors.red);
          } else {
            // Success path
            if (state.videoUrl.isNotEmpty &&
                state.isVideoLoaded &&
                !_isNavigatingToPlayer) {
              // print("asdfnsdflsddsadasjfkljsdlfjsd");
              // print(
              //   "asdfnsdflsddsadasjfkljsdlfjsd${state.videoOnParticulerChannelList}",
              // );
              // print(
              //   "asdfnsdflsddsadasjfkljsdlfjsd${state.selectedVideo.toString()}",
              // );
              // selectedVideo accessed inline below

              // print("========== SELECTED VIDEO ==========");
              // print("I= SELECTED VIDEO ======D: ${video?.streamId}");

              // print(
              //   'Video URL ready → navigating to player: ${state.selectedVideo}',
              // );
              final int resumeSeconds = int.tryParse(state.resumeSeconds) ?? 0;

              _navigateToPlayer(
                state.videoUrl,
                state.streamIDMovie,
                resumeSeconds,
              );
            } else if (state.status == Status.success && state.isStopLoader) {
              // print("asdfnsdflsdjfkljsdlfjsd");
              if (isLoaderRunning) stopLoader(context);
            }
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _isPhone ? 0 : 40.0),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: GeoLocationBanner(),
              ),
              Expanded(
                child: Row(
                  children: [
                    // ── Left: Category list ───────────────────────────────────────
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          if (isSearchChannelOnTextField)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: SizedBox(
                                height: 45,
                                child: CustomTextFormFiled(
                                  isOnChanged: true,
                                  onChanged: (newValue) {
                                    _onSearchDebounced(newValue, true);
                                  },
                                  controller: categorySearchCtrl,
                                  hintText: 'Search Categories...',
                                ),
                              ),
                            ),
                          Expanded(
                            child: Channels(
                              urlTillChannel: finalUrl,
                              playListId: widget.playListId,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // ── Right: Stream grid ────────────────────────────────────────
                    Expanded(
                      flex: 10,
                      child: Column(
                        children: [
                          if (!isSearchChannelOnTextField)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: SizedBox(
                                height: 45,
                                child: CustomTextFormFiled(
                                  isOnChanged: true,
                                  onChanged: (newValue) {
                                    _onSearchDebounced(newValue, false);
                                  },
                                  controller: streamSearchCtrl,
                                  hintText: 'Search Streams...',
                                ),
                              ),
                            ),
                          Expanded(
                            child: ShowPlaylistVideoInGrid(
                              urlTillChannel: finalUrl,
                              isMovies: widget.isMovies,
                              playListId: widget.playListId,
                              seriesID: "1914",
                              isSeries: widget.isSeries,
                              streamSearchCtrl: streamSearchCtrl,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
