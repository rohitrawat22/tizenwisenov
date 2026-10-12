import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Video screen for Samsung Tizen TV (flutter-tizen) with full logging.
///
/// pubspec.yaml needs:
///   video_player: ^2.8.0
///   video_player_tizen: ^0.x.x   (latest)
///
/// tizen/tizen-manifest.xml needs:
///   <privileges>
///     <privilege>http://tizen.org/privilege/internet</privilege>
///   </privileges>
///
/// Usage:
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => const TizenVideoScreen(
///       videoUrl: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
///     ),
///   ));

const String kMp4TestUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

void _log(String msg) {
  final line = '[TIZEN_VIDEO ${DateTime.now().toIso8601String()}] $msg';
  debugPrint(line);
  dev.log(line, name: 'TIZEN_VIDEO');
}

class TizenVideoScreen extends StatefulWidget {
  final String videoUrl;

  /// If the main URL fails to initialize, this URL is tried automatically.
  /// Set to null to disable the fallback.
  final String? fallbackUrl;
  final String title;
  final bool isLiveTv;

  const TizenVideoScreen({
    super.key,
    this.videoUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    this.fallbackUrl = kMp4TestUrl,
    this.title = 'Video',
    this.isLiveTv = false,
  });

  @override
  State<TizenVideoScreen> createState() => _TizenVideoScreenState();
}

class _TizenVideoScreenState extends State<TizenVideoScreen> {
  VideoPlayerController? _controller;
  final FocusNode _focusNode = FocusNode(debugLabel: 'tizen_video_root');

  bool _isReady = false;
  bool _hasError = false;
  String _errorText = 'Stream is currently unavailable.';
  bool _controlsVisible = true;
  bool _usingFallback = false;
  Timer? _hideTimer;
  Timer? _heartbeat;
  VideoPlayerValue? _last;

  @override
  void initState() {
    super.initState();
    _log('initState | url=${widget.videoUrl} | isLive=${widget.isLiveTv}');
    _log('platform=$defaultTargetPlatform | isWeb=$kIsWeb');
    _startHeartbeat();
    _initPlayer(widget.videoUrl);
  }

  void _startHeartbeat() {
    _heartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
      final v = _controller?.value;
      if (v == null) {
        _log('HEARTBEAT controller=null');
        return;
      }
      _log(
        'HEARTBEAT init=${v.isInitialized} playing=${v.isPlaying} '
        'buffering=${v.isBuffering} pos=${v.position} dur=${v.duration} '
        'size=${v.size} buffered=${v.buffered}',
      );
    });
  }

  Future<void> _disposeController() async {
    final old = _controller;
    _controller = null;
    if (old != null) {
      old.removeListener(_onControllerUpdate);
      try {
        await old.dispose();
      } catch (e) {
        _log('dispose old controller error: $e');
      }
    }
  }

  Future<void> _initPlayer(String url) async {
    final uri = Uri.parse(url);
    _log('Parsed URI: scheme=${uri.scheme} host=${uri.host} path=${uri.path}');

    await _disposeController();
    _last = null;

    // NOTE: no custom httpHeaders on purpose; video_player_tizen may
    // ignore or mishandle them and the okhttp User-Agent is Android-only.
    final controller = VideoPlayerController.networkUrl(
      uri,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _controller = controller;
    _log('Controller created');
    controller.addListener(_onControllerUpdate);

    try {
      _log('Calling initialize()...');
      final sw = Stopwatch()..start();
      await controller.initialize().timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            throw TimeoutException('initialize() timed out after 20s'),
      );
      _log('initialize() OK in ${sw.elapsedMilliseconds}ms');
      _log('value after init: ${controller.value}');

      if (!mounted || _controller != controller) {
        _log('Widget unmounted or controller replaced after init, abort');
        return;
      }

      _log('Calling play()...');
      await controller.play();
      _log('play() returned | isPlaying=${controller.value.isPlaying}');

      if (!mounted) return;
      setState(() {
        _isReady = true;
        _hasError = false;
      });
      _log('_isReady = true');
      _showControls();
    } catch (e, st) {
      _log('!!! INIT ERROR ($url): $e');
      _log('STACK: $st');
      if (e is PlatformException) {
        _log(
          'PlatformException code=${e.code} '
          'message=${e.message} details=${e.details}',
        );
      }
      if (!mounted) return;

      final fb = widget.fallbackUrl;
      if (!_usingFallback && fb != null && fb.isNotEmpty && fb != url) {
        _log('Trying fallback URL: $fb');
        _usingFallback = true;
        await _initPlayer(fb);
        return;
      }

      setState(() {
        _hasError = true;
        _errorText = 'Stream is currently unavailable.\n$e';
      });
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    final l = _last;

    if (l == null || l.isInitialized != v.isInitialized) {
      _log('EVENT isInitialized=${v.isInitialized}');
    }
    if (l == null || l.isPlaying != v.isPlaying) {
      _log('EVENT isPlaying=${v.isPlaying}');
    }
    if (l == null || l.isBuffering != v.isBuffering) {
      _log('EVENT isBuffering=${v.isBuffering}');
    }
    if (l == null || l.isCompleted != v.isCompleted) {
      _log('EVENT isCompleted=${v.isCompleted}');
    }
    if (l == null || l.size != v.size) {
      _log('EVENT size=${v.size}');
    }
    if (l == null || l.duration != v.duration) {
      _log('EVENT duration=${v.duration}');
    }
    if (v.hasError && (l == null || !l.hasError)) {
      _log('!!! EVENT PLAYER ERROR: ${v.errorDescription}');
    }
    _last = v;

    if (v.hasError && !_hasError) {
      setState(() {
        _hasError = true;
        _errorText = 'Playback error.\n${v.errorDescription ?? ''}';
      });
    } else {
      setState(() {});
    }
  }

  // ── Controls visibility ────────────────────────────────────────────────
  void _showControls() {
    _hideTimer?.cancel();
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────
  void _togglePlayPause() {
    final c = _controller;
    if (c == null) return;
    final playing = c.value.isPlaying;
    _log('ACTION togglePlayPause (was playing=$playing)');
    playing ? c.pause() : c.play();
    _showControls();
  }

  Future<void> _seekBy(int seconds) async {
    final c = _controller;
    if (c == null || widget.isLiveTv || !_isReady) {
      _log('ACTION seekBy ignored (live=${widget.isLiveTv}, ready=$_isReady)');
      return;
    }
    final pos = c.value.position;
    final dur = c.value.duration;
    var target = pos + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > dur) target = dur;
    _log('ACTION seekBy $seconds | $pos -> $target');
    await c.seekTo(target);
    _showControls();
  }

  // ── Samsung remote handling ────────────────────────────────────────────
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    _log(
      'KEY ${event.runtimeType} logical=${event.logicalKey.keyLabel} '
      '(${event.logicalKey.keyId}) physical=${event.physicalKey.debugName}',
    );
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlayPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      _controller?.play();
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      _controller?.pause();
      _showControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaStop) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.mediaFastForward) {
      _seekBy(10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.mediaRewind) {
      _seekBy(-10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      _showControls();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _log('dispose');
    _heartbeat?.cancel();
    _hideTimer?.cancel();
    final c = _controller;
    _controller = null;
    c?.removeListener(_onControllerUpdate);
    c?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final value = controller?.value;
    final totalDuration = value?.duration ?? Duration.zero;
    final position = value?.position ?? Duration.zero;
    final progress = (_isReady && totalDuration.inMilliseconds > 0)
        ? (position.inMilliseconds / totalDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Video ──
            if (_isReady && controller != null && value != null)
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio > 0
                      ? value.aspectRatio
                      : 16 / 9,
                  child: VideoPlayer(controller),
                ),
              ),

            // ── Loading ──
            if (!_isReady && !_hasError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _usingFallback
                          ? 'Trying fallback stream...'
                          : 'Loading...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Buffering indicator ──
            if (_isReady && (value?.isBuffering ?? false))
              const Center(child: CircularProgressIndicator(color: Colors.red)),

            // ── Error ──
            if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Text(
                    _errorText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 22),
                  ),
                ),
              ),

            // ── Overlay (title + play state + seek bar) ──
            if (_isReady && value != null)
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Stack(
                    children: [
                      // Top: title
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(48, 32, 48, 40),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              if (widget.isLiveTv)
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '● LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Center: play/pause icon
                      Center(
                        child: Icon(
                          value.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 84,
                        ),
                      ),

                      // Bottom: seek bar + time
                      if (!widget.isLiveTv)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(48, 40, 48, 32),
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.25,
                                    ),
                                    valueColor: const AlwaysStoppedAnimation(
                                      Colors.red,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _fmt(position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _fmt(totalDuration),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
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
          ],
        ),
      ),
    );
  }
}
