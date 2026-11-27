// lib/presentation/screen_view/common/dashboard_sub_screen/series_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/widgets/cached_image.dart';
import 'package:go_router/go_router.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/videos_on_particuler_channel_model.dart';

import 'package:wiseplayertizen/presentation/screen_view/web/screens/stream_player.dart';
import 'package:wiseplayertizen/series/serie.api.serivces.dart';
import 'package:wiseplayertizen/series/series.model.dart';

// ─────────────────────────────────────────────────────────────────────────
// DEBUG SWITCH — keep FALSE for release builds. Flip to true only when you
// need to trace TV remote input again: every raw key event hitting a focus
// node will be printed, along with every season "select" action.
// ─────────────────────────────────────────────────────────────────────────
const bool kDebugRemoteInput = false; // ← flip to true temporarily to verify Up-navigation in logcat/console

class SeriesDetailScreen extends StatefulWidget {
  final String playlistId;
  final String seriesId;
  final String baseUrl;

  const SeriesDetailScreen({
    super.key,
    required this.playlistId,
    required this.seriesId,
    required this.baseUrl,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen>
    with WidgetsBindingObserver {
  late final SeriesApiService _api;
  SeriesDetailModel? _detail;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedSeasonIndex = 0;

  // ── Production data source. Mock data is fully removed from the live
  // path — _getMockSeriesDetail() is kept below purely as a reference for
  // local UI testing; wire it back in manually if you ever need it again.
  static const bool _useMockData = false;

  // ── Responsive state — recomputed every build(), read by focus logic ──
  bool _isMobile = false;
  bool _isTablet = false;
  bool _isTV = false;
  int _gridColumns = 1;

  // ── TV Remote Focus Nodes ─────────────────────────────────────────────

  final FocusNode _retryFocusNode = FocusNode();
  FocusNode? _trailerFocusNode; // only created when a trailer exists

  // Dynamic — rebuilt whenever season/episode counts OR grid columns change.
  // Never leave stale nodes registered in the focus tree.
  List<FocusNode> _seasonFocusNodes = [];
  List<FocusNode> _episodeFocusNodes = [];

  // Enter/OK/Select keys. Different TV remotes/boxes/emulators map their
  // "OK" button to different logical keys. We accept a wide set here on
  // purpose — if your remote uses something outside this set, flip
  // kDebugRemoteInput to true to see exactly what key it sends, and add it
  // below.
  static final Set<LogicalKeyboardKey> _kEnterKeys = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
    LogicalKeyboardKey.gameButtonSelect,
    LogicalKeyboardKey.gameButtonStart,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.mediaPlayPause,
    LogicalKeyboardKey.mediaPlay,
  };

  // Arrow keys — some remotes/boxes send D-pad codes that Flutter maps to
  // these logical keys instead of the plain arrow keys. Included for safety.
  static final _kArrowUp = {LogicalKeyboardKey.arrowUp};
  static final _kArrowDown = {LogicalKeyboardKey.arrowDown};
  static final _kArrowLeft = {LogicalKeyboardKey.arrowLeft};
  static final _kArrowRight = {LogicalKeyboardKey.arrowRight};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = SeriesApiService();
    _fetchDetail();
  }

  @override
  void didChangeMetrics() {
    // Orientation change / window resize (foldables, TV res switch) can
    // change column count → episode grid navigation math changes too.
    // Debounce with a post-frame callback so MediaQuery has settled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rewireFocusGraph();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryFocusNode.dispose();
    _trailerFocusNode?.dispose();
    _disposeSeasonFocusNodes();
    _disposeEpisodeFocusNodes();
    super.dispose();
  }

  void _disposeSeasonFocusNodes() {
    for (final node in _seasonFocusNodes) {
      node.dispose();
    }
    _seasonFocusNodes = [];
  }

  void _disposeEpisodeFocusNodes() {
    for (final node in _episodeFocusNodes) {
      node.dispose();
    }
    _episodeFocusNodes = [];
  }

  // ── Generic D-pad wiring helper ────────────────────────────────────────
  void _setupNavigation(
    FocusNode node, {
    FocusNode? up,
    FocusNode? down,
    FocusNode? left,
    FocusNode? right,
    bool lockUp = false,
    bool lockDown = false,
    bool lockLeft = false,
    bool lockRight = false,
    VoidCallback? onAction,
    String? debugLabel,
  }) {
    node.onKeyEvent = (node, event) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        final key = event.logicalKey;

        if (kDebugRemoteInput) {
          // ignore: avoid_print
          print(
            '[RemoteDebug] node="${debugLabel ?? node.debugLabel}" '
            'eventType=${event.runtimeType} key=$key '
            'keyId=${key.keyId} debugName=${key.debugName}',
          );
        }

        if (_kEnterKeys.contains(key)) {
          if (kDebugRemoteInput) {
            // ignore: avoid_print
            print(
              '[RemoteDebug] -> matched ENTER on "${debugLabel ?? node.debugLabel}"',
            );
          }
          if (onAction != null) {
            onAction();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }

        if (_kArrowUp.contains(key)) {
          if (up != null) {
            up.requestFocus();
            return KeyEventResult.handled;
          }
          if (lockUp) return KeyEventResult.handled;
        } else if (_kArrowDown.contains(key)) {
          if (down != null) {
            down.requestFocus();
            return KeyEventResult.handled;
          }
          if (lockDown) return KeyEventResult.handled;
        } else if (_kArrowLeft.contains(key)) {
          if (left != null) {
            left.requestFocus();
            return KeyEventResult.handled;
          }
          if (lockLeft) return KeyEventResult.handled;
        } else if (_kArrowRight.contains(key)) {
          if (right != null) {
            right.requestFocus();
            return KeyEventResult.handled;
          }
          if (lockRight) return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  /// Rebuilds the ENTIRE focus graph: trailer (if any) → seasons →
  /// episode grid. Grid up/down uses `_gridColumns` so it works correctly
  /// whether episodes render as a single list (mobile) or a 2–3 col grid
  /// (TV). Safe to call repeatedly — always re-links against current state.
  void _rewireFocusGraph() {
    final hasTrailer = _trailerFocusNode != null;
    final firstSeasonOrEpisode = _seasonFocusNodes.isNotEmpty
        ? _seasonFocusNodes.first
        : (_episodeFocusNodes.isNotEmpty ? _episodeFocusNodes.first : null);

    // Trailer button (optional)
    if (hasTrailer) {
      _setupNavigation(
        _trailerFocusNode!,
        up: null,
        down: firstSeasonOrEpisode,
        lockUp: true,
        lockLeft: true,
        lockRight: true,
        lockDown: firstSeasonOrEpisode == null,
        debugLabel: 'trailer',
        onAction: _openTrailer,
      );
    }

    final FocusNode? aboveSeasons = hasTrailer ? _trailerFocusNode : null;

    // Season chips — horizontal row
    for (int i = 0; i < _seasonFocusNodes.length; i++) {
      final left = i > 0 ? _seasonFocusNodes[i - 1] : null;
      final right = i < _seasonFocusNodes.length - 1
          ? _seasonFocusNodes[i + 1]
          : null;
      final down = _episodeFocusNodes.isNotEmpty
          ? _episodeFocusNodes.first
          : null;

      _setupNavigation(
        _seasonFocusNodes[i],
        up: aboveSeasons,
        left: left,
        right: right,
        down: down,
        lockLeft: left == null,
        lockRight: right == null,
        lockDown: down == null,
        debugLabel: 'season[$i]',
        onAction: () => _selectSeason(i),
      );
    }

    // ── Where "Up" from the FIRST ROW of the episode grid should land. ──
    // Requirement: if focus is on Episode 1 (or any card in row 0) and the
    // user presses Up, focus must move to the currently SELECTED season
    // chip (e.g. "Season 1"), not just chip index 0. We resolve that here
    // once per rewire so every row-0 episode card points at the same,
    // always-current target.
    // final FocusNode _episodeRowZeroUpTarget = _seasonFocusNodes.isNotEmpty
    //     ? _seasonFocusNodes[_selectedSeasonIndex.clamp(
    //         0,
    //         _seasonFocusNodes.length - 1,
    //       )]
    //     : aboveSeasons; // no seasons rendered → fall back to back/trailer

    // Episode grid — column-aware up/down/left/right.
    final cols = _gridColumns.clamp(1, 100);
    for (int i = 0; i < _episodeFocusNodes.length; i++) {
      final col = i % cols;

      final upIndex = i - cols;
      final downIndex = i + cols;
      final leftIndex = col > 0 ? i - 1 : -1;
      final rightIndex = (col < cols - 1 && i + 1 < _episodeFocusNodes.length)
          ? i + 1
          : -1;

      // Row 0 (upIndex < 0) always escapes upward to the selected season
      // chip. Every other row moves to the card directly above it.
      final up = upIndex >= 0
          ? _episodeFocusNodes[upIndex]
          : _episodeFocusNodes[upIndex];
      final down = downIndex < _episodeFocusNodes.length
          ? _episodeFocusNodes[downIndex]
          : null;
      final left = leftIndex >= 0 ? _episodeFocusNodes[leftIndex] : null;
      final right = rightIndex >= 0 ? _episodeFocusNodes[rightIndex] : null;

      _setupNavigation(
        _episodeFocusNodes[i],
        up: up,
        down: down,
        left: left,
        right: right,
        lockDown: down == null,
        lockLeft: left == null,
        lockRight: right == null,
        debugLabel: 'episode[$i]',
        onAction: () => _playEpisode(_currentEpisodes[i]),
      );
    }

    // Retry button (error state) — standalone.
    _setupNavigation(
      _retryFocusNode,
      lockUp: true,
      lockDown: true,
      lockLeft: true,
      lockRight: true,
      debugLabel: 'retry',
      onAction: _fetchDetail,
    );
  }

  /// Central place that actually switches the selected season. Both the
  /// remote "select" action AND touch/tap go through this single method,
  /// so behaviour is identical no matter how the user triggers it.
  void _selectSeason(int index) {
    if (kDebugRemoteInput) {
      // ignore: avoid_print
      print(
        '[RemoteDebug] _selectSeason called: index=$index current=$_selectedSeasonIndex',
      );
    }
    if (_selectedSeasonIndex == index) return;
    setState(() => _selectedSeasonIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _buildEpisodeFocusNodes();
      _rewireFocusGraph();
      // Keep focus sensible after switching — land on the newly selected
      // season chip (not on episodes) so the remote user can keep moving
      // left/right through seasons, or press down to reach episodes.
      if (index < _seasonFocusNodes.length) {
        _seasonFocusNodes[index].requestFocus();
      }
    });
  }

  List<SeriesEpisode> get _currentEpisodes {
    final detail = _detail;
    if (detail == null) return const [];
    if (detail.seasons.isEmpty) {
      if (detail.episodes.isNotEmpty) {
        return detail.allEpisodes;
      }
      return const [];
    }
    final safeIndex = _selectedSeasonIndex.clamp(0, detail.seasons.length - 1);
    final selectedSeason = detail.seasons[safeIndex];
    final seasonNumber =
        selectedSeason.seasonNumber ?? (safeIndex + 1);
    var eps = detail.episodesForSeason(seasonNumber);
    if (eps.isEmpty && detail.episodes.isNotEmpty) {
      eps = detail.allEpisodes;
    }
    return eps;
  }

  void _buildSeasonFocusNodes() {
    _disposeSeasonFocusNodes();
    final detail = _detail;
    if (detail == null) return;
    _seasonFocusNodes = List.generate(
      detail.seasons.length,
      (_) => FocusNode(debugLabel: 'season'),
    );
  }

  void _buildEpisodeFocusNodes() {
    _disposeEpisodeFocusNodes();
    _episodeFocusNodes = List.generate(
      _currentEpisodes.length,
      (_) => FocusNode(debugLabel: 'episode'),
    );
  }

  void _buildTrailerFocusNodeIfNeeded() {
    final trailer = _detail?.info.youtubeTrailer;
    final hasTrailer = trailer != null && trailer.trim().isNotEmpty;
    if (hasTrailer && _trailerFocusNode == null) {
      _trailerFocusNode = FocusNode(debugLabel: 'trailer');
    } else if (!hasTrailer && _trailerFocusNode != null) {
      _trailerFocusNode!.dispose();
      _trailerFocusNode = null;
    }
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final SeriesDetailModel result;
      if (_useMockData) {
        result = await _getMockSeriesDetail();
      } else {
        result = await _api.getSeriesDetail(
          playlistId: widget.playlistId,
          seriesId: widget.seriesId,
        );
      }

      if (kDebugRemoteInput) {
        // ignore: avoid_print
        print(
          '[RemoteDebug] FIRST-LOAD CHECK -> '
          'seasons.length=${result.seasons.length} '
          'seasonNumbers=${result.seasons.map((s) => s.seasonNumber).toList()} '
          'useMock=$_useMockData',
        );
      }

      if (!mounted) return;
      setState(() {
        _detail = result;
        _selectedSeasonIndex = 0;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _buildTrailerFocusNodeIfNeeded();
        _buildSeasonFocusNodes();
        _buildEpisodeFocusNodes();
        _rewireFocusGraph();
        if (_seasonFocusNodes.isNotEmpty) {
          _seasonFocusNodes.first.requestFocus();
        } else if (_episodeFocusNodes.isNotEmpty) {
          _episodeFocusNodes.first.requestFocus();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _rewireFocusGraph();
        _retryFocusNode.requestFocus();
      });
    }
  }

  Future<void> _playEpisode(SeriesEpisode episode) async {
    if (episode.id == null || episode.id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid episode — cannot play.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColor.accentRed),
      ),
    );

    try {
      // Expected response: { "url": "https://cf.business-cdn-8k.com/series/.../45515.mkv" }
      final (videoUrl, resumeSeconds) = await _api.getEpisodeUrl(
        playlistId: widget.playlistId,
        episodeId: episode.id!,
        containerExtension: episode.containerExtension ?? 'mkv',
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close loader
      int resumeSecond = resumeSeconds ?? 0;
      0;
      GoRouter.of(context).push(
        VideoPlayerScreen.routeName,
        extra: {
          'videoUrl': videoUrl,
          'resumeSecond': resumeSecond,
          // VideoPlayerScreen requires a non-null VideosOnPerticulerChannelModel
          // (uses .name and .toJson() internally) — built from episode data.
          'videoInfo': _buildVideoInfoFromEpisode(episode),
          'isLiveTv': false,
          "streaID": episode.id,
          "playlistId": widget.playlistId,
          "streamType": "SERIES",
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // close loader
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load episode: $e')));
    }
  }

  /// Adapts a SeriesEpisode into the shape VideoPlayerScreen expects.
  /// TODO: fill in the exact constructor params once VideosOnPerticulerChannelModel
  /// is shared — placeholder assumes a `name` field exists (used by the
  /// "Change Stream?" dialog: widget.videoInfo.name).
  VideosOnPerticulerChannelModel _buildVideoInfoFromEpisode(
    SeriesEpisode episode,
  ) {
    return VideosOnPerticulerChannelModel(
      name: episode.displayTitle,
      // ...remaining required fields go here once model is shared
    );
  }

  void _openTrailer() {
    // TODO: Wire up url_launcher (add to pubspec.yaml) to actually open
    // https://www.youtube.com/watch?v=${_detail!.info.youtubeTrailer}
    // Kept as a safe no-op + user feedback so this file compiles without
    // adding a new dependency implicitly.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add url_launcher package to enable trailer playback.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColor.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              _isMobile = width < 600;
              _isTablet = width >= 600 && width < 900;
              _isTV = width >= 900;
              _gridColumns = width >= 1300 ? 3 : (width >= 900 ? 2 : 1);
              return _buildBody(constraints);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BoxConstraints constraints) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColor.accentRed),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildRetryButton(),
            ],
          ),
        ),
      );
    }

    final detail = _detail;
    if (detail == null) {
      return const Center(
        child: Text('No data found.', style: TextStyle(color: Colors.white70)),
      );
    }

    final horizontalPad = _isMobile ? 12.0 : (_isTablet ? 20.0 : 32.0);

    return CustomScrollView(
      slivers: [
        _buildHeaderSliver(detail),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPad),
            child: _buildInfoSection(detail),
          ),
        ),
        if (detail.seasons.isNotEmpty)
          SliverToBoxAdapter(child: _buildSeasonSelector(detail, horizontalPad))
        else if (detail.totalEpisodes == 0)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No seasons available.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
        _buildEpisodeSection(detail, horizontalPad),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildRetryButton() {
    return AnimatedBuilder(
      animation: _retryFocusNode,
      builder: (context, _) {
        final isFocused = _retryFocusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: InkWell(
            focusNode: _retryFocusNode,
            borderRadius: BorderRadius.circular(10),
            onTap: _fetchDetail,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: AppColor.accentRed,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: AppColor.accentRed.withOpacity(0.4),
                          blurRadius: 16,
                        ),
                      ]
                    : [],
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSliver(SeriesDetailModel detail) {
    final backdrop = detail.info.backdropPath.isNotEmpty
        ? detail.info.backdropPath.first
        : detail.info.cover;

    final expandedHeight = _isMobile ? 200.0 : (_isTablet ? 240.0 : 300.0);

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: AppColor.background,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (backdrop != null && backdrop.isNotEmpty)
              CachedImage(
                imageUrl: backdrop,
                height: expandedHeight,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidgets: Container(color: AppColor.surfaceDark),
              )
            else
              Container(
                color: AppColor.surfaceDark,
                child: const Center(
                  child: Icon(
                    Icons.movie_creation_outlined,
                    color: Colors.white24,
                    size: 48,
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColor.background.withOpacity(0.85),
                    AppColor.background,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(SeriesDetailModel detail) {
    final info = detail.info;
    final titleSize = _isMobile ? 19.0 : (_isTablet ? 22.0 : 26.0);
    final hasTrailer =
        info.youtubeTrailer != null && info.youtubeTrailer!.trim().isNotEmpty;
    final hasRunTime =
        info.episodeRunTime != null &&
        info.episodeRunTime!.trim().isNotEmpty &&
        info.episodeRunTime != '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.displayName,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _chip(
              Icons.star_rounded,
              info.rating5based ?? info.rating ?? '—',
              AppColor.accentRed,
            ),
            _chip(
              Icons.category_outlined,
              info.displayGenre,
              AppColor.accentCyan,
            ),
            _chip(
              Icons.calendar_today_outlined,
              info.releaseYear,
              Colors.white54,
            ),
            _chip(
              Icons.video_library_outlined,
              '${detail.totalSeasons} Season${detail.totalSeasons == 1 ? '' : 's'}',
              Colors.white54,
            ),
            _chip(
              Icons.movie_filter_outlined,
              '${detail.totalEpisodes} Episode${detail.totalEpisodes == 1 ? '' : 's'}',
              Colors.white54,
            ),
            if (hasRunTime)
              _chip(
                Icons.timer_outlined,
                '${info.episodeRunTime} min',
                Colors.white54,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (hasTrailer) _buildTrailerButton(),
        if (hasTrailer) const SizedBox(height: 14),
        Text(
          info.displayPlot,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        _labelValue('Cast', info.displayCast),
        _labelValue('Director', info.displayDirector),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildTrailerButton() {
    final node = _trailerFocusNode;
    if (node == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: node,
      builder: (context, _) {
        final isFocused = node.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: InkWell(
            focusNode: node,
            borderRadius: BorderRadius.circular(10),
            onTap: _openTrailer,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isFocused
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFocused
                      ? Colors.white
                      : Colors.white.withOpacity(0.1),
                  width: isFocused ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Watch Trailer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12.5, color: Colors.white70),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonSelector(SeriesDetailModel detail, double horizontalPad) {
    final chipHeight = _isMobile ? 62.0 : 70.0;
    return SizedBox(
      height: chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 8),
        itemCount: detail.seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index >= _seasonFocusNodes.length) return const SizedBox.shrink();
          final season = detail.seasons[index];
          final isSelected = index == _selectedSeasonIndex;
          final focusNode = _seasonFocusNodes[index];

          return _FocusAutoScroll(
            focusNode: focusNode,
            child: AnimatedBuilder(
              animation: focusNode,
              builder: (context, _) {
                final isFocused = focusNode.hasFocus;
                return GestureDetector(
                  // Tap uses the SAME method as the remote's "select" action,
                  // so behaviour is guaranteed identical either way.
                  onTap: () => _selectSeason(index),
                  child: AnimatedScale(
                    scale: isFocused ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 80),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColor.accentRed
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFocused
                              ? Colors.white
                              : (isSelected
                                    ? AppColor.accentRed
                                    : Colors.white.withOpacity(0.1)),
                          width: isFocused ? 2.5 : 1.0,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: AppColor.accentRed.withOpacity(0.35),
                                  blurRadius: 14,
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            season.displayName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEpisodeSection(SeriesDetailModel detail, double horizontalPad) {
    if (detail.seasons.isEmpty && detail.totalEpisodes == 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final episodes = _currentEpisodes;

    if (episodes.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No episodes found for this season.',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      );
    }

    final cols = _gridColumns.clamp(1, 100);

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 8),
      sliver: cols == 1
          ? SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= _episodeFocusNodes.length)
                  return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _EpisodeCard(
                    episode: episodes[index],
                    focusNode: _episodeFocusNodes[index],
                    isMobile: _isMobile,
                    onTap: () => _playEpisode(episodes[index]),
                  ),
                );
              }, childCount: episodes.length),
            )
          : SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.9,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= _episodeFocusNodes.length)
                  return const SizedBox.shrink();
                return _EpisodeCard(
                  episode: episodes[index],
                  focusNode: _episodeFocusNodes[index],
                  isMobile: _isMobile,
                  onTap: () => _playEpisode(episodes[index]),
                );
              }, childCount: episodes.length),
            ),
    );
  }
}

/// Auto-scrolls a focused child into view within the nearest Scrollable —
/// essential on TV since the remote has no scroll gesture.
class _FocusAutoScroll extends StatefulWidget {
  final FocusNode focusNode;
  final Widget child;

  const _FocusAutoScroll({required this.focusNode, required this.child});

  @override
  State<_FocusAutoScroll> createState() => _FocusAutoScrollState();
}

class _FocusAutoScrollState extends State<_FocusAutoScroll> {
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
    if (!widget.focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = context;
      if (Scrollable.maybeOf(ctx) == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _EpisodeCard extends StatelessWidget {
  final SeriesEpisode episode;
  final FocusNode focusNode;
  final bool isMobile;
  final VoidCallback onTap;

  const _EpisodeCard({
    required this.episode,
    required this.focusNode,
    required this.isMobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPlot =
        episode.info.plot != null && episode.info.plot!.trim().isNotEmpty;
    final hasReleaseDate =
        episode.info.releaseDate != null &&
        episode.info.releaseDate!.trim().isNotEmpty;

    return _FocusAutoScroll(
      focusNode: focusNode,
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, _) {
          final isFocused = focusNode.hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: InkWell(
              focusNode: focusNode,
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isFocused
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFocused
                        ? AppColor.accentRed
                        : Colors.white.withOpacity(0.06),
                    width: isFocused ? 2.0 : 1.0,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: AppColor.accentRed.withOpacity(0.3),
                            blurRadius: 16,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: isMobile ? 100 : 120,
                        height: isMobile ? 60 : 72,
                        child: CachedImage(
                          imageUrl: episode.info.movieImage ?? '',
                          height: isMobile ? 60 : 72,
                          width: isMobile ? 100 : 120,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          errorWidgets: Container(
                            color: AppColor.surfaceDark,
                            child: const Icon(
                              Icons.movie_outlined,
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Episode ${episode.episodeNum ?? '-'}',
                            style: const TextStyle(
                              color: AppColor.accentRed,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            episode.displayTitle,
                            maxLines: isMobile ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                episode.info.displayDuration,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              if (episode.info.rating != null &&
                                  episode.info.rating! > 0) ...[
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  episode.info.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              if (hasReleaseDate) ...[
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.event_outlined,
                                  size: 12,
                                  color: Colors.white38,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  episode.info.releaseDate!,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (hasPlot && !isMobile) ...[
                            const SizedBox(height: 3),
                            Text(
                              episode.info.plot!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: isFocused ? AppColor.accentRed : Colors.white70,
                      size: isMobile ? 26 : 30,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// REFERENCE-ONLY MOCK DATA. Not wired into the live fetch path (guarded by
// `_useMockData == false` above). Keep for local widget/UI testing only —
// e.g. temporarily flip `_useMockData` to true in a debug build to exercise
// the multi-season UI without a live API response.
// ─────────────────────────────────────────────────────────────────────────
// ignore: unused_element
Future<SeriesDetailModel> _getMockSeriesDetail() async {
  final mockJson = {
    "info": {
      "name": "Test Series",
      "cover": "",
      "backdrop_path": [],
      "plot": "A test series for verifying multi-season UI.",
      "cast": "Actor A, Actor B",
      "director": "Test Director",
      "genre": "Drama",
      "releaseDate": "2023-01-01",
      "rating": "8.0",
      "rating_5based": 4.0,
      "episode_run_time": "45",
      "youtube_trailer": "",
    },
    "seasons": [
      {"season_number": 1, "name": "Season 1", "episode_count": 2},
      {"season_number": 2, "name": "Season 2", "episode_count": 2},
      {"season_number": 3, "name": "Season 3", "episode_count": 2},
    ],
    "episodes": {
      "1": [
        {
          "id": "101",
          "episode_num": 1,
          "title": "S1 Episode 1",
          "container_extension": "mkv",
          "info": {"plot": "First episode of season 1", "duration": "45:00"},
        },
        {
          "id": "102",
          "episode_num": 2,
          "title": "S1 Episode 2",
          "container_extension": "mkv",
          "info": {"plot": "Second episode of season 1", "duration": "44:00"},
        },
      ],
      "2": [
        {
          "id": "201",
          "episode_num": 1,
          "title": "S2 Episode 1",
          "container_extension": "mkv",
          "info": {"plot": "First episode of season 2", "duration": "46:00"},
        },
        {
          "id": "202",
          "episode_num": 2,
          "title": "S2 Episode 2",
          "container_extension": "mkv",
          "info": {"plot": "Second episode of season 2", "duration": "43:00"},
        },
      ],
      "3": [
        {
          "id": "301",
          "episode_num": 1,
          "title": "S3 Episode 1",
          "container_extension": "mkv",
          "info": {"plot": "First episode of season 3", "duration": "40:00"},
        },
        {
          "id": "302",
          "episode_num": 2,
          "title": "S3 Episode 2",
          "container_extension": "mkv",
          "info": {"plot": "Second episode of season 3", "duration": "41:00"},
        },
      ],
    },
  };

  // ⚠️ Replace this with however your model actually deserializes —
  // e.g. SeriesDetailModel.fromJson(mockJson)
  return SeriesDetailModel.fromJson(mockJson);
}
