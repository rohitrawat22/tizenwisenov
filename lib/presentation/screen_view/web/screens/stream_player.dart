import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/utils/breakpoints.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/series/serie.api.serivces.dart';

import '../../../../core/routes/routes_path.dart';
import '../../bloc/model/videos_on_particuler_channel_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EPG program model — mirrors the "programs" array from the EPG API response
// (id, channelId, title, description, startTs, endTs, progressPercent,
// remainingSeconds, running, past). Pass a List<EpgProgramModel>? in from
// whatever screen already fetches the EPG JSON — this widget never fetches
// it itself.
// ─────────────────────────────────────────────────────────────────────────────
class EpgProgramModel {
  final String id;
  final String channelId;
  final String title;
  final String description;
  final int startTs; // epoch seconds
  final int endTs; // epoch seconds
  final bool catchupAvailable;
  final int? progressPercent;
  final int? remainingSeconds;
  final bool running;
  final bool past;

  const EpgProgramModel({
    required this.id,
    required this.channelId,
    required this.title,
    required this.description,
    required this.startTs,
    required this.endTs,
    this.catchupAvailable = false,
    this.progressPercent,
    this.remainingSeconds,
    this.running = false,
    this.past = false,
  });

  factory EpgProgramModel.fromJson(Map<String, dynamic> json) {
    return EpgProgramModel(
      id: json['id']?.toString() ?? '',
      channelId: json['channelId']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startTs: (json['startTs'] as num?)?.toInt() ?? 0,
      endTs: (json['endTs'] as num?)?.toInt() ?? 0,
      catchupAvailable: json['catchupAvailable'] as bool? ?? false,
      progressPercent: (json['progressPercent'] as num?)?.toInt(),
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt(),
      running: json['running'] as bool? ?? false,
      past: json['past'] as bool? ?? false,
    );
  }

  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(startTs * 1000);
  DateTime get endTime => DateTime.fromMillisecondsSinceEpoch(endTs * 1000);

  /// Uses progressPercent from the API when present; otherwise derives it
  /// live from the current time vs. startTs/endTs so the bar still moves.
  double get progressFraction {
    if (progressPercent != null) {
      return progressPercent!.clamp(0, 100) / 100.0;
    }
    final totalSeconds = endTs - startTs;
    if (totalSeconds <= 0) return 0;
    final elapsed = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - startTs;
    return elapsed.clamp(0, totalSeconds) / totalSeconds;
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String streaID;
  final String playlistId;
  final VideosOnPerticulerChannelModel videoInfo;
  final bool isLiveTv;
  final int? resumeSecond;

  /// NEW — required for progress tracking. "VOD" or "SERIES".
  /// Pass null (or omit) for content that shouldn't be tracked (e.g. live TV).
  final String? streamType;

  /// NEW — EPG program list for the Live TV drawer. Nullable: pass it in
  /// once the calling screen has fetched/parsed the EPG JSON. When null (or
  /// empty) the drawer still opens and shows an empty state instead of
  /// crashing. Ignored entirely when [isLiveTv] is false.
  final List<EpgProgramModel>? programList;

  static const routeName = AppRoutes.videoPlayer;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.videoInfo,
    required this.streaID,
    required this.playlistId,
    required this.resumeSecond,
    this.isLiveTv = true,
    this.streamType,
    this.programList,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isPlayerReady = false;
  String? _playerError;

  bool _isPhone = false;
  bool _isInitialized = false;

  // ── Progress tracking state ────────────────────────────────────────────
  final SeriesApiService _seriesApiService = SeriesApiService();
  Timer? _progressTimer;
  int _lastKnownPositionSeconds = 0;
  int _lastSentPositionSeconds = -1; // avoid firing duplicate calls
  int _durationSeconds = 0;

  // ── EPG drawer state ────────────────────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FocusNode _drawerMenuFocusNode = FocusNode(
    debugLabel: 'epg_drawer_menu_button',
  );
  final FocusNode _closeButtonFocusNode = FocusNode(
    debugLabel: 'epg_drawer_close_button',
  );
  final Map<int, FocusNode> _epgFocusNodes = {};

  // ── Live TV custom overlay FocusNodes ──────────────────────────────────
  final FocusNode _overlayBackFocusNode = FocusNode(debugLabel: 'overlay_back');
  final FocusNode _overlayPlayFocusNode = FocusNode(debugLabel: 'overlay_play');
  final FocusNode _overlayEpgFocusNode = FocusNode(debugLabel: 'overlay_epg');

  // ── VOD custom overlay FocusNodes ─────────────────────────────────────
  final FocusNode _vodBackFocusNode = FocusNode(debugLabel: 'vod_back');
  final FocusNode _vodPlayFocusNode = FocusNode(debugLabel: 'vod_play');
  final FocusNode _vodSeekBarFocusNode = FocusNode(debugLabel: 'vod_seekbar');

  /// Only track progress for content that has a valid streamId + streamType.
  /// Live TV is excluded by design (per backend doc, progress is for VOD/SERIES).
  bool get _shouldTrackProgress =>
      !widget.isLiveTv && widget.streamType != null && _streamId != null;

  String? get _streamId {
    return widget.streaID;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // print('fsdfsdfsd${widget.videoUrl}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isPhone = isPhoneWidth(context);
      _isInitialized = true;
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    // print('fsdfdsa🎈🎈dasdasdsdfsd${widget.videoUrl}');
    log('''
Stream Player Details:
videoUrl  : ${widget.videoUrl}
streaID   : ${widget.streaID}
videoInfo : ${widget.videoInfo.toJson()}
isLiveTv  : ${widget.isLiveTv}
''');

    if (_isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    BlocProvider.of<WiseBloc>(context).add(ResetVideoUrlEvent());

    final uri = Uri.parse(widget.videoUrl);
    final isHls = widget.isLiveTv || uri.path.toLowerCase().endsWith('.m3u8');
    final controller = VideoPlayerController.networkUrl(
      uri,
      formatHint: isHls ? VideoFormat.hls : null,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    _playerError = null;
    controller.addListener(_onPlayerUpdate);

    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;

      final resumeSeconds = widget.resumeSecond ?? 0;
      if (!widget.isLiveTv && resumeSeconds > 0) {
        await controller.seekTo(Duration(seconds: resumeSeconds));
      }
      await controller.play();
      if (!mounted || _controller != controller) return;

      setState(() {
        _isPlayerReady = true;
        _durationSeconds = controller.value.duration.inSeconds;
        _lastKnownPositionSeconds = controller.value.position.inSeconds;
      });
    } catch (error, stackTrace) {
      log(
        'Video player initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted || _controller != controller) return;
      setState(() {
        _playerError = error.toString();
        _isPlayerReady = false;
      });
    }

    // ── Start the "heartbeat" — fires every 12s while playing ──────────
    if (_shouldTrackProgress) {
      _progressTimer = Timer.periodic(const Duration(seconds: 12), (_) {
        _sendProgress();
      });
    }
  }

  void _onPlayerUpdate() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    final value = controller.value;
    if (value.hasError) {
      setState(
        () => _playerError = value.errorDescription ?? 'Playback failed.',
      );
      return;
    }
    if (!value.isInitialized) return;

    _lastKnownPositionSeconds = value.isCompleted
        ? value.duration.inSeconds
        : value.position.inSeconds;
    _durationSeconds = value.duration.inSeconds;
    if (!_isPlayerReady) setState(() => _isPlayerReady = true);
    if (_shouldTrackProgress && !value.isPlaying) _sendProgress();
  }

  /// Fires the progress API. Fully async/fire-and-forget — never blocks
  /// the UI or shows a spinner, per the integration doc.
  void _sendProgress() {
    if (!_shouldTrackProgress) return;
    if (_lastKnownPositionSeconds <= 0) return;
    if (_lastKnownPositionSeconds == _lastSentPositionSeconds) return; // no-op

    final String streamId = _streamId!;
    final String streamType = widget.streamType!;
    final int position = _lastKnownPositionSeconds;
    final int duration = _durationSeconds;

    _lastSentPositionSeconds = position;

    unawaited(
      _seriesApiService
          .postWatchProgress(
            playlistId: widget.playlistId,
            streamId: streamId,
            streamType: streamType,
            positionSeconds: position,
            durationSeconds: duration,
          )
          .catchError((e) {
            // Swallow errors — progress reporting must never crash playback.
            log('postWatchProgress failed: $e');
            return false;
          }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On background/kill, make a best-effort attempt to save the last
    // known position before the OS reclaims the app.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _sendProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();

    // Final save before leaving the screen.
    _sendProgress();

    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onPlayerUpdate);
    controller?.dispose();

    _drawerMenuFocusNode.dispose();
    _closeButtonFocusNode.dispose();
    _overlayBackFocusNode.dispose();
    _overlayPlayFocusNode.dispose();
    _overlayEpgFocusNode.dispose();
    _vodBackFocusNode.dispose();
    _vodPlayFocusNode.dispose();
    _vodSeekBarFocusNode.dispose();
    for (final node in _epgFocusNodes.values) {
      node.dispose();
    }
    _epgFocusNodes.clear();

    if (_isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  /// Shows the premium "Change Video?" confirmation dialog.
  Future<bool> _showChangeVideoDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (dialogCtx) => _ChangeVideoDialog(
        streamName: widget.videoInfo.name ?? 'this stream',
      ),
    );
    return result == true;
  }

  // ── EPG drawer helpers ──────────────────────────────────────────────────

  FocusNode _epgFocusNode(int index) {
    return _epgFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'epg_program_$index'),
    );
  }

  /// direction: -1 = move focus up, 1 = move focus down.
  /// CHANGED: currentIndex == -1 is now a sentinel meaning "focus is
  /// currently on the close button". This lets focus travel seamlessly
  /// between the header's close button and row 0 of the list, in both
  /// directions, instead of dead-ending at the top of the list.
  void _moveEpgFocus(int currentIndex, int direction, int total) {
    if (currentIndex == -1) {
      // Focus is on the close button.
      if (direction == 1 && total > 0) {
        _epgFocusNode(0).requestFocus();
      }
      return;
    }

    final targetIndex = currentIndex + direction;
    if (targetIndex < 0) {
      // CHANGED: walking up off row 0 now lands on the close button
      // instead of doing nothing.
      _closeButtonFocusNode.requestFocus();
      return;
    }
    if (targetIndex >= total) return;
    _epgFocusNode(targetIndex).requestFocus();
  }

  /// CHANGED: single place that decides where focus should land the
  /// moment the drawer opens. Previously this only happened by accident,
  /// inside a tile's initState, and only if that tile was the "running"
  /// program — so with no running program (or an empty list) the drawer
  /// opened with nothing focused and the remote couldn't do anything.
  void _focusInitialEpgElement() {
    final programs = widget.programList ?? const <EpgProgramModel>[];
    final runningIndex = programs.indexWhere((p) => p.running);
    if (runningIndex != -1) {
      _epgFocusNode(runningIndex).requestFocus();
    } else if (programs.isNotEmpty) {
      _epgFocusNode(0).requestFocus();
    } else {
      _closeButtonFocusNode.requestFocus();
    }
  }

  Widget _buildEpgDrawerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 10, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColor.accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColor.accentRed.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.live_tv_rounded,
              color: AppColor.accentRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Programme Guide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.videoInfo.name ?? 'Live TV',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // CHANGED: plain IconButton replaced with a focusable, D-pad
          // aware close button (see _EpgCloseButton below).
          _EpgCloseButton(
            focusNode: _closeButtonFocusNode,
            onTap: () => Navigator.of(context).pop(),
            onMoveFocus: (direction) {
              final total =
                  (widget.programList ?? const <EpgProgramModel>[]).length;
              _moveEpgFocus(-1, direction, total);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEpgEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
              color: Colors.white.withValues(alpha: 0.25),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'No programme data yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpgDrawer() {
    final programs = widget.programList ?? const <EpgProgramModel>[];
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth < 700
        ? screenWidth * 0.86
        : (screenWidth * 0.34).clamp(320.0, 420.0);

    return Drawer(
      backgroundColor: const Color(0xFF0A0706),
      width: drawerWidth,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            _buildEpgDrawerHeader(),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: programs.isEmpty
                  ? _buildEpgEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                      itemCount: programs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _EpgProgramTile(
                          program: programs[index],
                          focusNode: _epgFocusNode(index),
                          onMoveFocus: (direction) =>
                              _moveEpgFocus(index, direction, programs.length),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
          // Save progress before actually leaving the player.
          _sendProgress();
          nav.pop();
        }
      },
      child: Focus(
        autofocus: false, // Don't steal autofocus from the initial nodes
        canRequestFocus: false, // This is just a passive listener
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.mediaPlayPause) {
              final controller = _controller;
              if (controller == null) return KeyEventResult.handled;
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.mediaFastForward ||
                key == LogicalKeyboardKey.mediaTrackNext) {
              if (_isPlayerReady) {
                final current = _controller?.value.position ?? Duration.zero;
                _controller?.seekTo(current + const Duration(seconds: 10));
              }
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.mediaRewind ||
                key == LogicalKeyboardKey.mediaTrackPrevious) {
              if (_isPlayerReady) {
                final current = _controller?.value.position ?? Duration.zero;
                final target = current - const Duration(seconds: 10);
                _controller?.seekTo(
                  target < Duration.zero ? Duration.zero : target,
                );
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.black,
          // Drawer only exists for Live TV — VOD/series never get an EPG.
          drawer: widget.isLiveTv ? _buildEpgDrawer() : null,
          // CHANGED: this is the hook that fires the moment the drawer
          // finishes opening/closing. We use it to push remote focus onto
          // the drawer as soon as it's visible — previously nothing did
          // this reliably, which is also why the remote sometimes "did
          // nothing" right after pressing the menu button.
          onDrawerChanged: (isOpened) {
            if (isOpened) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _focusInitialEpgElement();
              });
            }
          },
          body: Stack(
            children: [
              // Player or loading spinner
              _isPlayerReady && _controller != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio > 0
                            ? _controller!.value.aspectRatio
                            : 16 / 9,
                        child: RepaintBoundary(
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    )
                  : _playerError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.signal_wifi_bad_rounded,
                              color: Colors.white38,
                              size: 56,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Stream is currently unavailable or unsupported on this device.\n$_playerError',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: AppColor.accentRed,
                      ),
                    ),

              // ── Custom TV-first overlay for Live streams ──────────────
              // Replaces the old single EPG button. The overlay shows on
              // any D-pad / remote keypress and auto-hides after 4 seconds.
              // It exposes Back, Play/Pause, and EPG as individually
              // focusable icons so the TV remote can reach each one.
              if (widget.isLiveTv && _isPlayerReady && _controller != null)
                _LiveTvControlsOverlay(
                  controller: _controller!,
                  backFocusNode: _overlayBackFocusNode,
                  playFocusNode: _overlayPlayFocusNode,
                  epgFocusNode: _overlayEpgFocusNode,
                  channelName: widget.videoInfo.name ?? 'Live TV',
                  onEpgOpen: () => _scaffoldKey.currentState?.openDrawer(),
                  onBack: () async {
                    final navigator = Navigator.of(context);
                    final shouldLeave = await _showChangeVideoDialog();
                    if (shouldLeave && mounted) {
                      _sendProgress();
                      navigator.pop();
                    }
                  },
                ),

              // ── Custom VOD overlay for Movies / Series ───────────────
              // Shows seek bar, play/pause, rewind/forward, back + title.
              // D-pad Left/Right on the seek bar jumps ±10 seconds.
              if (!widget.isLiveTv && _isPlayerReady && _controller != null)
                _VodControlsOverlay(
                  controller: _controller!,
                  backFocusNode: _vodBackFocusNode,
                  playFocusNode: _vodPlayFocusNode,
                  seekBarFocusNode: _vodSeekBarFocusNode,
                  title: widget.videoInfo.name ?? 'Video',
                  onBack: () async {
                    final navigator = Navigator.of(context);
                    final shouldLeave = await _showChangeVideoDialog();
                    if (shouldLeave && mounted) {
                      _sendProgress();
                      navigator.pop();
                    }
                  },
                ),
            ],
          ),
        ), // closes Scaffold
      ), // closes Focus
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live TV custom D-pad overlay
// ─────────────────────────────────────────────────────────────────────────────

class _LiveTvControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final FocusNode backFocusNode;
  final FocusNode playFocusNode;
  final FocusNode epgFocusNode;
  final String channelName;
  final VoidCallback onEpgOpen;
  final VoidCallback onBack;

  const _LiveTvControlsOverlay({
    required this.controller,
    required this.backFocusNode,
    required this.playFocusNode,
    required this.epgFocusNode,
    required this.channelName,
    required this.onEpgOpen,
    required this.onBack,
  });

  @override
  State<_LiveTvControlsOverlay> createState() => _LiveTvControlsOverlayState();
}

class _LiveTvControlsOverlayState extends State<_LiveTvControlsOverlay>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _isPlaying = true;
  Timer? _hideTimer;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    widget.controller.addListener(_onPlayerUpdate);

    // Default initial focus lands on Play/Pause
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.playFocusNode.requestFocus();
    });
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    final isPlaying = widget.controller.value.isPlaying;
    if (_isPlaying != isPlaying) setState(() => _isPlaying = isPlaying);
  }

  void _showControls() {
    if (!_visible) {
      setState(() => _visible = true);
      _animCtrl.forward();
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _animCtrl.reverse().then((_) {
          if (mounted) setState(() => _visible = false);
        });
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    setState(() => _isPlaying = !_isPlaying);
    _showControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animCtrl.dispose();
    widget.controller.removeListener(_onPlayerUpdate);
    super.dispose();
  }

  Widget _buildIconBtn({
    required IconData icon,
    required FocusNode focusNode,
    required VoidCallback onTap,
    required String tooltip,
    double iconSize = 28,
    bool isMain = false,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        return Focus(
          focusNode: focusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              // LEFT/RIGHT navigation between icons
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (focusNode == widget.playFocusNode) {
                  widget.backFocusNode.requestFocus();
                  _showControls();
                  return KeyEventResult.handled;
                } else if (focusNode == widget.epgFocusNode) {
                  widget.playFocusNode.requestFocus();
                  _showControls();
                  return KeyEventResult.handled;
                }
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if (focusNode == widget.backFocusNode) {
                  widget.playFocusNode.requestFocus();
                  _showControls();
                  return KeyEventResult.handled;
                } else if (focusNode == widget.playFocusNode) {
                  widget.epgFocusNode.requestFocus();
                  _showControls();
                  return KeyEventResult.handled;
                }
              }
              // UP/DOWN: show controls without doing anything else
              if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _showControls();
                return KeyEventResult.ignored;
              }
              // SELECT / ENTER triggers the action
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter) {
                onTap();
                return KeyEventResult.handled;
              }
              // Any other key: show overlay so user knows controls are accessible
              _showControls();
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: () {
              _showControls();
              onTap();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: EdgeInsets.all(isMain ? 16 : 12),
              decoration: BoxDecoration(
                color: isFocused
                    ? AppColor.accentRed
                    : Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFocused
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  width: isFocused ? 2.5 : 1,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: AppColor.accentRed.withValues(alpha: 0.5),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Tooltip(
                message: tooltip,
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isFocused ? iconSize + 4 : iconSize,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // The whole screen is a key listener — any D-pad press reveals controls
    return KeyboardListener(
      focusNode: FocusNode()..skipTraversal = true,
      onKeyEvent: (e) {
        if (e is KeyDownEvent) _showControls();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _showControls();
          widget.playFocusNode.requestFocus();
        },
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Stack(
            children: [
              // Bottom gradient scrim
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
              // Channel name top-left
              Positioned(
                top: 20,
                left: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.accentRed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '● LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.channelName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                  ],
                ),
              ),
              // Control buttons — centered horizontally at the bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIconBtn(
                      icon: Icons.arrow_back_rounded,
                      focusNode: widget.backFocusNode,
                      onTap: widget.onBack,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    _buildIconBtn(
                      icon: _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      focusNode: widget.playFocusNode,
                      onTap: _togglePlayPause,
                      tooltip: _isPlaying ? 'Pause' : 'Play',
                      iconSize: 34,
                      isMain: true,
                    ),
                    const SizedBox(width: 8),
                    _buildIconBtn(
                      icon: Icons.live_tv_rounded,
                      focusNode: widget.epgFocusNode,
                      // EPG only opens on explicit SELECT — not on focus.
                      onTap: widget.onEpgOpen,
                      tooltip: 'Programme Guide (EPG)',
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

// ─────────────────────────────────────────────────────────────────────────────
// VOD custom D-pad overlay — for Movies and Series
// Shows a seek bar, play/pause, rewind/forward, back button + title.
// D-pad Left/Right on the seek bar jumps ±10 seconds.
// ─────────────────────────────────────────────────────────────────────────────

class _VodControlsOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final FocusNode backFocusNode;
  final FocusNode playFocusNode;
  final FocusNode seekBarFocusNode;
  final String title;
  final VoidCallback onBack;

  const _VodControlsOverlay({
    required this.controller,
    required this.backFocusNode,
    required this.playFocusNode,
    required this.seekBarFocusNode,
    required this.title,
    required this.onBack,
  });

  @override
  State<_VodControlsOverlay> createState() => _VodControlsOverlayState();
}

class _VodControlsOverlayState extends State<_VodControlsOverlay>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  bool _isPlaying = true;
  Timer? _hideTimer;
  late AnimationController _animCtrl;

  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 1); // avoid /0
  Duration _buffered = Duration.zero;

  // Seek feedback animation
  String? _seekFeedback; // '« 10s' or '10s »'
  Timer? _seekFeedbackTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    widget.controller.addListener(_onPlayerUpdate);

    // Default initial focus lands on Play/Pause
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.playFocusNode.requestFocus();
    });
  }

  void _onPlayerUpdate() {
    if (!mounted) return;
    final value = widget.controller.value;
    if (!value.isInitialized) return;
    final bufferedRanges = value.buffered;
    setState(() {
      _isPlaying = value.isPlaying;
      _position = value.position;
      _duration = value.duration > Duration.zero
          ? value.duration
          : const Duration(seconds: 1);
      if (bufferedRanges.isNotEmpty) _buffered = bufferedRanges.last.end;
    });
  }

  void _showControls() {
    if (!_visible) {
      setState(() => _visible = true);
      _animCtrl.forward();
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _animCtrl.reverse().then((_) {
          if (mounted) setState(() => _visible = false);
        });
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    setState(() => _isPlaying = !_isPlaying);
    _showControls();
  }

  void _seekRelative(int seconds) {
    final newPos = _position + Duration(seconds: seconds);
    final clamped = Duration(
      milliseconds: newPos.inMilliseconds.clamp(0, _duration.inMilliseconds),
    );
    widget.controller.seekTo(clamped);
    setState(() {
      _position = clamped;
      _seekFeedback = seconds < 0 ? '« ${seconds.abs()}s' : '${seconds}s »';
    });
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
    _showControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _animCtrl.dispose();
    widget.controller.removeListener(_onPlayerUpdate);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final double bufferedProgress = _duration.inMilliseconds > 0
        ? (_buffered.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return KeyboardListener(
      focusNode: FocusNode()..skipTraversal = true,
      onKeyEvent: (e) {
        if (e is KeyDownEvent) _showControls();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _showControls();
          widget.playFocusNode.requestFocus();
        },
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_visible,
            child: Stack(
              children: [
                // ── Top gradient scrim ──
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Bottom gradient scrim ──
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Top bar: Back button + Title ──
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      _VodIconBtn(
                        icon: Icons.arrow_back_rounded,
                        focusNode: widget.backFocusNode,
                        onTap: widget.onBack,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowDown) {
                              widget.playFocusNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                            if (event.logicalKey == LogicalKeyboardKey.select ||
                                event.logicalKey == LogicalKeyboardKey.enter) {
                              widget.onBack();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Center: Seek feedback pulse ──
                if (_seekFeedback != null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _seekFeedback!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                // ── Center: Play/Pause button ──
                Center(
                  child: _VodIconBtn(
                    icon: _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    focusNode: widget.playFocusNode,
                    size: 56,
                    iconSize: 36,
                    onTap: _togglePlayPause,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          widget.backFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          widget.seekBarFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          _seekRelative(-10);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _seekRelative(10);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          _togglePlayPause();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                  ),
                ),

                // ── Bottom: Seek bar + timestamps ──
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Focus(
                    focusNode: widget.seekBarFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          _seekRelative(-10);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _seekRelative(10);
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          widget.playFocusNode.requestFocus();
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.select ||
                            event.logicalKey == LogicalKeyboardKey.enter) {
                          _togglePlayPause();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Seek bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: widget.seekBarFocusNode.hasFocus ? 8 : 4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                // Background track
                                Container(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                // Buffered
                                FractionallySizedBox(
                                  widthFactor: bufferedProgress,
                                  child: Container(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                ),
                                // Played
                                FractionallySizedBox(
                                  widthFactor: progress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColor.accentRed,
                                          AppColor.accentRed.withValues(
                                            alpha: 0.8,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                // Seek handle (thumb)
                                Positioned(
                                  left:
                                      (MediaQuery.of(context).size.width - 40) *
                                          progress -
                                      6,
                                  top: 0,
                                  bottom: 0,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: widget.seekBarFocusNode.hasFocus
                                        ? 14
                                        : 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow:
                                          widget.seekBarFocusNode.hasFocus
                                          ? [
                                              BoxShadow(
                                                color: AppColor.accentRed
                                                    .withValues(alpha: 0.6),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : [],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Timestamps
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            // Remaining time
                            Text(
                              '-${_formatDuration(_duration - _position)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── VOD icon button helper ──────────────────────────────────────────────────
class _VodIconBtn extends StatelessWidget {
  final IconData icon;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback? onKeyEvent;
  final double size;
  final double iconSize;

  const _VodIconBtn({
    required this.icon,
    required this.focusNode,
    required this.onTap,
    this.onKeyEvent,
    this.size = 44,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        return Focus(
          focusNode: focusNode,
          onKeyEvent: onKeyEvent,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isFocused ? size + 8 : size,
              height: isFocused ? size + 8 : size,
              decoration: BoxDecoration(
                color: isFocused
                    ? AppColor.accentRed
                    : Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isFocused
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  width: isFocused ? 2.5 : 1,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: AppColor.accentRed.withValues(alpha: 0.5),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isFocused ? iconSize + 4 : iconSize,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── rest of the file (_ChangeVideoDialog, _DialogButton) unchanged ───────

// ─────────────────────────────────────────────────────────────────────────────
// Premium "Change Video?" dialog — glassmorphic dark design, D-pad navigable
// ─────────────────────────────────────────────────────────────────────────────
class _ChangeVideoDialog extends StatefulWidget {
  final String streamName;

  const _ChangeVideoDialog({required this.streamName});

  @override
  State<_ChangeVideoDialog> createState() => _ChangeVideoDialogState();
}

class _ChangeVideoDialogState extends State<_ChangeVideoDialog>
    with SingleTickerProviderStateMixin {
  final FocusNode _cancelNode = FocusNode(debugLabel: 'dialog_cancel');
  final FocusNode _changeNode = FocusNode(debugLabel: 'dialog_change');

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(
      begin: 0.90,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    // D-pad: right on Cancel → Change
    _cancelNode.onKeyEvent = (node, event) {
      if (event is! KeyUpEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _changeNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // D-pad: left on Change → Cancel
    _changeNode.onKeyEvent = (node, event) {
      if (event is! KeyUpEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _cancelNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    // Auto-focus Cancel so user can immediately press back again to cancel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cancelNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelNode.dispose();
    _changeNode.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _cancel() {
    Navigator.of(context).pop(false); // returns false → stream continues
  }

  void _confirmChange() {
    Navigator.of(context).pop(true); // returns true → caller will pop player
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final bool isSmallScreen = screenHeight < 500;
    final double hPad = screenWidth < 500
        ? 20.0
        : (screenWidth < 900 ? 24.0 : 40.0);
    final double vPad = isSmallScreen ? 8.0 : 60.0;

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: screenHeight * 0.95,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A0808),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColor.accentRed.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  28,
                  isSmallScreen ? 20 : 32,
                  28,
                  isSmallScreen ? 20 : 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Icon (hidden on small screens) ────────────────────
                    if (!isSmallScreen)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColor.accentRed.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColor.accentRed.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.swap_horiz_rounded,
                          color: AppColor.accentRed,
                          size: 36,
                        ),
                      ),

                    if (!isSmallScreen) const SizedBox(height: 20),

                    // ── Title ─────────────────────────────────────────────
                    Text(
                      'Change Stream?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: isSmallScreen ? 6 : 8),

                    // ── Stream name ────────────────────────────────────────
                    Text(
                      widget.streamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: isSmallScreen ? 13 : 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 24),

                    // ── Action Buttons ─────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _DialogButton(
                            focusNode: _cancelNode,
                            label: 'Stay',
                            icon: Icons.play_arrow_rounded,
                            isPrimary: false,
                            onTap: _cancel,
                            isSmallScreen: isSmallScreen,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _DialogButton(
                            focusNode: _changeNode,
                            label: 'Change',
                            icon: Icons.swap_horiz_rounded,
                            isPrimary: true,
                            onTap: _confirmChange,
                            isSmallScreen: isSmallScreen,
                          ),
                        ),
                      ],
                    ),

                    // ── D-pad hint (hidden on small screens) ────────────────
                    if (!isSmallScreen) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chevron_left,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Use arrow keys to navigate',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable dialog button with focus animation
// ─────────────────────────────────────────────────────────────────────────────
class _DialogButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;
  final bool isSmallScreen;

  const _DialogButton({
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
    this.isSmallScreen = false,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusNode: widget.focusNode,
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: widget.isSmallScreen ? 44 : 52,
        decoration: BoxDecoration(
          color: _isFocused
              ? (widget.isPrimary
                    ? AppColor.accentRed
                    : Colors.white.withValues(alpha: 0.15))
              : (widget.isPrimary
                    ? AppColor.accentRed.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isFocused
                ? Colors.white
                : (widget.isPrimary
                      ? AppColor.accentRed.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.12)),
            width: _isFocused ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: _isFocused ? Colors.white : Colors.white60,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              widget.label,
              style: TextStyle(
                color: _isFocused ? Colors.white : Colors.white60,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small circular button (top-left, over the player) that opens the EPG
// drawer. D-pad "select"/"enter" triggers it too, matching remote-control
// behaviour on Android TV / Fire TV.
// ─────────────────────────────────────────────────────────────────────────────
class _EpgDrawerButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onTap;

  const _EpgDrawerButton({required this.focusNode, required this.onTap});

  @override
  State<_EpgDrawerButton> createState() => _EpgDrawerButtonState();
}

class _EpgDrawerButtonState extends State<_EpgDrawerButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyUpEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _isFocused
                ? AppColor.accentRed.withValues(alpha: 0.85)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: _isFocused ? 2.0 : 0.0,
            ),
          ),
          child: Icon(
            Icons.menu_rounded,
            color: Colors.white.withValues(alpha: _isFocused ? 1.0 : 0.85),
            size: 24,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEW: Focusable close button for the EPG drawer header.
// Mirrors _EpgDrawerButton's focus/select handling so the D-pad can reach
// and activate it, and forwards arrowDown so focus can travel from the
// header straight into row 0 of the programme list.
// ─────────────────────────────────────────────────────────────────────────────
class _EpgCloseButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onTap;
  final ValueChanged<int> onMoveFocus;

  const _EpgCloseButton({
    required this.focusNode,
    required this.onTap,
    required this.onMoveFocus,
  });

  @override
  State<_EpgCloseButton> createState() => _EpgCloseButtonState();
}

class _EpgCloseButtonState extends State<_EpgCloseButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          widget.onMoveFocus(1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isFocused
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            color: _isFocused ? Colors.white : Colors.white54,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One row in the EPG drawer. Shows title / time range / description, and —
// only for the currently `running` program — a "LIVE" badge plus a real
// progress bar driven by `progressPercent` from the API JSON.
// ─────────────────────────────────────────────────────────────────────────────
class _EpgProgramTile extends StatefulWidget {
  final EpgProgramModel program;
  final FocusNode focusNode;

  /// -1 = move focus to previous row, 1 = move focus to next row.
  final ValueChanged<int> onMoveFocus;

  const _EpgProgramTile({
    required this.program,
    required this.focusNode,
    required this.onMoveFocus,
  });

  @override
  State<_EpgProgramTile> createState() => _EpgProgramTileState();
}

class _EpgProgramTileState extends State<_EpgProgramTile> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);

    // CHANGED: initial-focus-on-open is now handled centrally by
    // _VideoPlayerScreenState._focusInitialEpgElement (via onDrawerChanged),
    // so this tile no longer grabs focus on its own. Two tiles independently
    // calling requestFocus() in the old code could race depending on build
    // order; centralizing it removes that race and also covers the
    // "nothing is running" case that the old code missed entirely.
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
    // CHANGED: this is the actual fix for "can't scroll the drawer with a
    // remote". Moving focus with the D-pad never told the ListView to
    // scroll — Flutter doesn't do that automatically for a Focus widget.
    // ensureVisible walks up to the nearest Scrollable (our ListView) and
    // animates it so the newly focused tile is on screen.
    if (widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final program = widget.program;
    final isRunning = program.running;
    final isPast = program.past;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onMoveFocus(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onMoveFocus(-1);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRunning
              ? AppColor.accentRed.withValues(alpha: _isFocused ? 0.22 : 0.12)
              : Colors.white.withValues(alpha: _isFocused ? 0.10 : 0.045),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isFocused
                ? Colors.white
                : (isRunning
                      ? AppColor.accentRed.withValues(alpha: 0.5)
                      : Colors.white12),
            width: _isFocused ? 1.6 : 1.0,
          ),
        ),
        child: Opacity(
          opacity: isPast ? 0.45 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isRunning)
                    Container(
                      margin: const EdgeInsets.only(right: 8, top: 1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColor.accentRed,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      program.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: isRunning
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatTime(program.startTime)} - ${_formatTime(program.endTime)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (program.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  program.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
              if (isRunning) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: program.progressFraction,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(
                      AppColor.accentRed,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  program.remainingSeconds != null
                      ? '${(program.remainingSeconds! / 60).ceil()} min left'
                      : '${(program.progressFraction * 100).round()}% watched',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
