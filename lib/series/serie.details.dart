// lib/series/serie.details.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/widgets/cached_image.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/videos_on_particuler_channel_model.dart';
import 'package:wiseplayertizen/presentation/screen_view/web/screens/stream_player.dart';
import 'package:wiseplayertizen/series/serie.api.serivces.dart';
import 'package:wiseplayertizen/series/series.model.dart';

// ─────────────────────────────────────────────────────────────────────────
// DEBUG SWITCH — keep FALSE for release builds. Flip to true only when you
// need to trace TV remote input in logcat/console: every raw key event
// hitting a focus node will be printed along with season & episode actions.
// ─────────────────────────────────────────────────────────────────────────
const bool kDebugRemoteInput = false;

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

  // ── Production data source switch ──────────────────────────────────────
  static const bool _useMockData = false;

  // ── Responsive state — recomputed on layout, read by focus logic ───────
  bool _isMobile = false;
  bool _isTablet = false;
  bool _isTV = false;
  int _gridColumns = 1;

  // ── Scroll Controllers for TV D-Pad Auto-Scroll ───────────────────────
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _seasonScrollController = ScrollController();

  // ── TV Remote Focus Nodes ─────────────────────────────────────────────

  final FocusNode _retryFocusNode = FocusNode(debugLabel: 'retry_button');
  FocusNode? _trailerFocusNode; // created dynamically when trailer is available

  // Persistent FocusNode caches (never destroyed during normal navigation)
  final Map<int, FocusNode> _seasonFocusNodes = {};
  final Map<int, FocusNode> _episodeFocusNodes = {};

  FocusNode _getSeasonNode(int index) {
    return _seasonFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'season_$index'),
    );
  }

  FocusNode _getEpisodeNode(int index) {
    return _episodeFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'episode_$index'),
    );
  }

  // ── TV Remote Key Sets ────────────────────────────────────────────────
  // Enter / Select / OK / Gamepad Action keys across various TV devices
  static final Set<LogicalKeyboardKey> _kEnterKeys = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
    LogicalKeyboardKey.gameButtonSelect,
    LogicalKeyboardKey.gameButtonStart,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.mediaPlay,
    LogicalKeyboardKey.mediaPlayPause,
  };

  // TV Remote Back / Escape keys
  static final Set<LogicalKeyboardKey> _kBackKeys = {
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.gameButtonB,
  };

  static final Set<LogicalKeyboardKey> _kArrowUp = {LogicalKeyboardKey.arrowUp};
  static final Set<LogicalKeyboardKey> _kArrowDown = {
    LogicalKeyboardKey.arrowDown,
  };
  static final Set<LogicalKeyboardKey> _kArrowLeft = {
    LogicalKeyboardKey.arrowLeft,
  };
  static final Set<LogicalKeyboardKey> _kArrowRight = {
    LogicalKeyboardKey.arrowRight,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = SeriesApiService();
    _fetchDetail();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rewireFocusGraph();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mainScrollController.dispose();
    _seasonScrollController.dispose();
    _retryFocusNode.dispose();
    _trailerFocusNode?.dispose();
    for (final node in _seasonFocusNodes.values) {
      node.dispose();
    }
    _seasonFocusNodes.clear();
    for (final node in _episodeFocusNodes.values) {
      node.dispose();
    }
    _episodeFocusNodes.clear();
    super.dispose();
  }

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
            '[RemoteDebug] node="${debugLabel ?? node.debugLabel}" key=$key debugName=${key.debugName}',
          );
        }

        if (_kEnterKeys.contains(key)) {
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

  void _rewireFocusGraph() {
    final detail = _detail;
    final seasonCount = detail?.seasons.length ?? 0;
    final episodes = _currentEpisodes;
    final episodeCount = episodes.length;

    final hasTrailer = _trailerFocusNode != null;

    final FocusNode? firstSeasonNode = seasonCount > 0
        ? _getSeasonNode(0)
        : null;
    final FocusNode? selectedSeasonNode = seasonCount > 0
        ? _getSeasonNode(_selectedSeasonIndex.clamp(0, seasonCount - 1))
        : null;
    final FocusNode? firstEpisodeNode = episodeCount > 0
        ? _getEpisodeNode(0)
        : null;

    final FocusNode? topContentFirstFocus =
        selectedSeasonNode ?? firstSeasonNode ?? firstEpisodeNode;

    // 1. Trailer button navigation (optional)
    if (hasTrailer && _trailerFocusNode != null) {
      _setupNavigation(
        _trailerFocusNode!,
        up: null,
        down: topContentFirstFocus,
        lockUp: true,
        lockLeft: true,
        lockRight: true,
        lockDown: topContentFirstFocus == null,
        debugLabel: 'trailer',
        onAction: _openTrailer,
      );
    }

    final FocusNode? aboveSeasonsTarget =
        hasTrailer && _trailerFocusNode != null ? _trailerFocusNode : null;

    // 3. Season chips (horizontal row navigation)
    for (int i = 0; i < seasonCount; i++) {
      final FocusNode node = _getSeasonNode(i);
      final FocusNode? left = i > 0 ? _getSeasonNode(i - 1) : null;
      final FocusNode? right = i < seasonCount - 1
          ? _getSeasonNode(i + 1)
          : null;
      final FocusNode? down = firstEpisodeNode;

      _setupNavigation(
        node,
        up: aboveSeasonsTarget,
        left: left,
        right: right,
        down: down,
        lockLeft: left == null,
        lockRight: right == null,
        lockDown: down == null,
        debugLabel: 'season_$i',
        onAction: () => _selectSeason(i),
      );
    }

    // 4. Episode grid (column-aware D-pad navigation)
    final cols = _gridColumns.clamp(1, 100);
    final FocusNode? episodeRowZeroUpTarget =
        selectedSeasonNode ?? aboveSeasonsTarget;

    for (int i = 0; i < episodeCount; i++) {
      final FocusNode node = _getEpisodeNode(i);
      final col = i % cols;

      final upIndex = i - cols;
      final downIndex = i + cols;
      final leftIndex = col > 0 ? i - 1 : -1;
      final rightIndex = (col < cols - 1 && i + 1 < episodeCount) ? i + 1 : -1;

      final FocusNode? up = upIndex >= 0
          ? _getEpisodeNode(upIndex)
          : episodeRowZeroUpTarget;
      final FocusNode? down = downIndex < episodeCount
          ? _getEpisodeNode(downIndex)
          : null;
      final FocusNode? left = leftIndex >= 0
          ? _getEpisodeNode(leftIndex)
          : null;
      final FocusNode? right = rightIndex >= 0
          ? _getEpisodeNode(rightIndex)
          : null;

      _setupNavigation(
        node,
        up: up,
        down: down,
        left: left,
        right: right,
        lockDown: down == null,
        lockLeft: left == null,
        lockRight: right == null,
        debugLabel: 'episode_$i',
        onAction: () => _playEpisode(episodes[i]),
      );
    }

    // 5. Retry button navigation
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

  void _selectSeason(int index) {
    if (kDebugRemoteInput) {
      // ignore: avoid_print
      print(
        '[RemoteDebug] _selectSeason: index=$index current=$_selectedSeasonIndex',
      );
    }
    setState(() {
      _selectedSeasonIndex = index;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _buildEpisodeFocusNodes();
      _rewireFocusGraph();
      _getSeasonNode(index).requestFocus();
    });
  }

  List<SeriesEpisode> get _currentEpisodes {
    final detail = _detail;
    if (detail == null || detail.seasons.isEmpty) return const [];
    final safeIndex = _selectedSeasonIndex.clamp(0, detail.seasons.length - 1);
    final selectedSeason = detail.seasons[safeIndex];
    final seasonNumber = selectedSeason.seasonNumber ?? (safeIndex + 1);

    // Multi-tier fallback lookup strategy for episodes across any backend key format
    var eps = detail.episodesForSeason(seasonNumber);
    if (eps.isEmpty) {
      eps = detail.episodes[seasonNumber.toString()] ?? const [];
    }
    if (eps.isEmpty) {
      eps = detail.episodes[(safeIndex + 1).toString()] ?? const [];
    }
    if (eps.isEmpty) {
      eps = detail.episodes[safeIndex.toString()] ?? const [];
    }
    if (eps.isEmpty && safeIndex < detail.episodes.length) {
      final keys = detail.episodes.keys.toList();
      eps = detail.episodes[keys[safeIndex]] ?? const [];
    }
    return eps;
  }

  void _buildSeasonFocusNodes() {
    if (_detail == null) return;
    for (int i = 0; i < _detail!.seasons.length; i++) {
      _getSeasonNode(i);
    }
  }

  void _buildEpisodeFocusNodes() {
    final episodes = _currentEpisodes;
    for (int i = 0; i < episodes.length; i++) {
      _getEpisodeNode(i);
    }
  }

  void _buildTrailerFocusNodeIfNeeded() {
    final trailer = _detail?.info.youtubeTrailer;
    final hasTrailer = trailer != null && trailer.trim().isNotEmpty;
    if (hasTrailer && _trailerFocusNode == null) {
      _trailerFocusNode = FocusNode(debugLabel: 'trailer_button');
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

        if (_detail != null && _detail!.seasons.isNotEmpty) {
          _getSeasonNode(0).requestFocus();
        } else if (_currentEpisodes.isNotEmpty) {
          _getEpisodeNode(0).requestFocus();
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
        const SnackBar(
          content: Text('Invalid episode details. Unable to play.'),
          backgroundColor: AppColor.accentRed,
        ),
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
      final (videoUrl, resumeSecondsFromVideo) = await _api.getEpisodeUrl(
        playlistId: widget.playlistId,
        episodeId: episode.id!,
        containerExtension: episode.containerExtension ?? 'mkv',
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      int resumeSecond = resumeSecondsFromVideo;

      bool hasWatchProgress = false;
      if (episode.watchProgress != null) {
        final raw = episode.watchProgress!.watchedPercent;
        final percent = double.tryParse(raw ?? '') ?? 0.0;
        if (percent > 0.0 && percent < 100.0) {
          hasWatchProgress = true;
        }
      }

      if (hasWatchProgress || resumeSecond > 0) {
        final result = await showResumeCancelDialog(context);
        switch (result) {
          case ResumeDialogResult.resume:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  videoUrl: videoUrl,
                  resumeSecond: resumeSecond,
                  videoInfo: _buildVideoInfoFromEpisode(episode),
                  isLiveTv: false,
                  streaID: episode.id ?? "",
                  playlistId: widget.playlistId,
                  streamType: "SERIES",
                ),
              ),
            );
            break;
          case ResumeDialogResult.restart:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  videoUrl: videoUrl,
                  resumeSecond: 0,
                  videoInfo: _buildVideoInfoFromEpisode(episode),
                  isLiveTv: false,
                  streaID: episode.id ?? "",
                  playlistId: widget.playlistId,
                  streamType: "SERIES",
                ),
              ),
            );
            break;
          case ResumeDialogResult.cancel:
            //   context.pop();
            break;
        }
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: videoUrl,
              resumeSecond: 0,
              videoInfo: _buildVideoInfoFromEpisode(episode),
              isLiveTv: false,
              streaID: episode.id ?? "",
              playlistId: widget.playlistId,
              streamType: "SERIES",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load episode stream: $e'),
          backgroundColor: AppColor.accentRed,
        ),
      );
    }
  }

  VideosOnPerticulerChannelModel _buildVideoInfoFromEpisode(
    SeriesEpisode episode,
  ) {
    final intId = int.tryParse(episode.id ?? '');
    return VideosOnPerticulerChannelModel(
      name: episode.displayTitle,
      streamId: intId,
      streamIcon: episode.info.movieImage,
      streamType: 'series',
      categoryId: widget.seriesId,
    );
  }

  Future<void> _openTrailer() async {
    final trailer = _detail?.info.youtubeTrailer;
    if (trailer == null || trailer.trim().isEmpty) return;

    final String cleanTrailer = trailer.trim();
    final Uri uri = cleanTrailer.startsWith('http')
        ? Uri.parse(cleanTrailer)
        : Uri.parse('https://www.youtube.com/watch?v=$cleanTrailer');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot launch trailer link: $cleanTrailer')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error launching trailer: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor: AppColor.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                _isMobile = width < 600;
                _isTablet = width >= 600 && width < 1100;
                _isTV = width >= 1100;
                _gridColumns = width >= 1300 ? 3 : (width >= 700 ? 2 : 1);
                return _buildBody(constraints);
              },
            ),
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
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildRetryButton(),
            ],
          ),
        ),
      );
    }

    final detail = _detail;
    if (detail == null) {
      return const Center(
        child: Text(
          'No series detail found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final horizontalPad = _isMobile ? 12.0 : (_isTablet ? 24.0 : 36.0);

    return CustomScrollView(
      controller: _mainScrollController,
      cacheExtent: 2500, // Keeps off-screen D-pad target cards alive in tree
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
        else
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
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildRetryButton() {
    return AnimatedBuilder(
      animation: _retryFocusNode,
      builder: (context, _) {
        final isFocused = _retryFocusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: InkWell(
            focusNode: _retryFocusNode,
            borderRadius: BorderRadius.circular(10),
            onTap: _fetchDetail,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                          color: AppColor.accentRed.withOpacity(0.5),
                          blurRadius: 18,
                        ),
                      ]
                    : [],
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
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

    final expandedHeight = _isMobile
        ? 200.0
        : (_isTablet ? 250.0 : (_isTV ? 320.0 : 280.0));

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
                    size: 54,
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
    final titleSize = _isMobile ? 20.0 : (_isTablet ? 24.0 : 28.0);
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
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
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
              Colors.white60,
            ),
            _chip(
              Icons.video_library_outlined,
              '${detail.totalSeasons} Season${detail.totalSeasons == 1 ? '' : 's'}',
              Colors.white60,
            ),
            _chip(
              Icons.movie_filter_outlined,
              '${detail.totalEpisodes} Episode${detail.totalEpisodes == 1 ? '' : 's'}',
              Colors.white60,
            ),
            if (hasRunTime)
              _chip(
                Icons.timer_outlined,
                '${info.episodeRunTime} min',
                Colors.white60,
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (hasTrailer) _buildTrailerButton(),
        if (hasTrailer) const SizedBox(height: 14),
        Text(
          info.displayPlot,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        _labelValue('Cast', info.displayCast),
        _labelValue('Director', info.displayDirector),
        const SizedBox(height: 8),
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
          scale: isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: InkWell(
            focusNode: node,
            borderRadius: BorderRadius.circular(10),
            onTap: _openTrailer,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isFocused
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFocused
                      ? Colors.white
                      : Colors.white.withOpacity(0.15),
                  width: isFocused ? 2.5 : 1.0,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.25),
                          blurRadius: 16,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Watch Trailer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
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
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
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
          style: const TextStyle(fontSize: 13, color: Colors.white70),
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
    final chipHeight = _isMobile ? 64.0 : 72.0;
    return SizedBox(
      height: chipHeight,
      child: ListView.separated(
        controller: _seasonScrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 8),
        itemCount: detail.seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final season = detail.seasons[index];
          final isSelected = index == _selectedSeasonIndex;
          final focusNode = _getSeasonNode(index);

          return _FocusAutoScroll(
            focusNode: focusNode,
            child: AnimatedBuilder(
              animation: focusNode,
              builder: (context, _) {
                final isFocused = focusNode.hasFocus;
                return InkWell(
                  focusNode: focusNode,
                  onTap: () => _selectSeason(index),
                  child: AnimatedScale(
                    scale: isFocused ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 80),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColor.accentRed
                            : (isFocused
                                  ? Colors.white.withOpacity(0.12)
                                  : Colors.white.withOpacity(0.06)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isFocused
                              ? Colors.white
                              : (isSelected
                                    ? AppColor.accentRed
                                    : Colors.white.withOpacity(0.12)),
                          width: isFocused ? 2.5 : 1.0,
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            season.displayName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: isSelected || isFocused
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
    if (detail.seasons.isEmpty) {
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EpisodeCard(
                    episode: episodes[index],
                    focusNode: _getEpisodeNode(index),
                    isMobile: _isMobile,
                    onTap: () => _playEpisode(episodes[index]),
                  ),
                );
              }, childCount: episodes.length),
            )
          : SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.85,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                return _EpisodeCard(
                  episode: episodes[index],
                  focusNode: _getEpisodeNode(index),
                  isMobile: _isMobile,
                  onTap: () => _playEpisode(episodes[index]),
                );
              }, childCount: episodes.length),
            ),
    );
  }
}

/// Auto-scrolls a focused child into view within the nearest Scrollable.
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

  double get _watchedPercent {
    final raw = episode.watchProgress?.watchedPercent;
    if (raw == null) return 0.0;
    final parsed = double.tryParse(raw) ?? 0.0;
    return parsed.clamp(0.0, 100.0);
  }

  bool get _hasProgress {
    final fully = episode.watchProgress?.fullyWatched == "true";
    return episode.watchProgress != null && (_watchedPercent > 0 || fully);
  }

  @override
  Widget build(BuildContext context) {
    final hasPlot =
        episode.info.plot != null && episode.info.plot!.trim().isNotEmpty;
    final hasReleaseDate =
        episode.info.releaseDate != null &&
        episode.info.releaseDate!.trim().isNotEmpty;
    final isFullyWatched = episode.watchProgress?.fullyWatched == "true";
    final progressPercent = isFullyWatched ? 100.0 : _watchedPercent;

    return _FocusAutoScroll(
      focusNode: focusNode,
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, _) {
          final isFocused = focusNode.hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: InkWell(
              focusNode: focusNode,
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isFocused
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFocused
                        ? AppColor.accentRed
                        : Colors.white.withOpacity(0.08),
                    width: isFocused ? 2.5 : 1.0,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: AppColor.accentRed.withOpacity(0.35),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: isMobile ? 100 : 120,
                        height: isMobile ? 62 : 74,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedImage(
                              imageUrl: episode.info.movieImage ?? '',
                              height: isMobile ? 62 : 74,
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
                            // Watch progress bar (Netflix-style red line)
                            if (_hasProgress)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  height: 4,
                                  color: Colors.black.withOpacity(0.35),
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: progressPercent / 100,
                                    child: Container(color: AppColor.accentRed),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
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
                              fontSize: 13.5,
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
                              if (_hasProgress) ...[
                                const SizedBox(width: 10),
                                Icon(
                                  isFullyWatched
                                      ? Icons.check_circle_rounded
                                      : Icons.play_circle_outline_rounded,
                                  size: 12,
                                  color: isFullyWatched
                                      ? Colors.greenAccent
                                      : AppColor.accentRed,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  isFullyWatched
                                      ? 'Watched'
                                      : '${progressPercent.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    color: isFullyWatched
                                        ? Colors.greenAccent
                                        : Colors.white38,
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
                    const SizedBox(width: 6),
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
// REFERENCE-ONLY MOCK DATA helper for local UI testing.
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

  return SeriesDetailModel.fromJson(mockJson);
}
// resume_dialog_basic.dart
//
// Basic Resume / Restart / Cancel dialog, styled to match the app's dark
// theme with a red accent (as seen in "Season 1" chip / episode labels).
// Includes TV remote D-pad navigation logic — wire your own actions inside
// each onSelect callback.

enum ResumeDialogResult { resume, restart, cancel }

Future<ResumeDialogResult> showResumeCancelDialog(BuildContext context) async {
  final result = await showDialog<ResumeDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ResumeDialog(),
  );
  return result ?? ResumeDialogResult.cancel;
}

class _ResumeDialog extends StatefulWidget {
  const _ResumeDialog();

  @override
  State<_ResumeDialog> createState() => _ResumeDialogState();
}

class _ResumeDialogState extends State<_ResumeDialog> {
  // 0 = Resume, 1 = Restart, 2 = Cancel
  int _focusedIndex = 0;

  final List<FocusNode> _nodes = List.generate(
    3,
    (i) => FocusNode(debugLabel: 'resume_dialog_btn_$i'),
  );

  static final Set<LogicalKeyboardKey> _kEnterKeys = {
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.gameButtonA,
    LogicalKeyboardKey.space,
  };

  static final Set<LogicalKeyboardKey> _kBackKeys = {
    LogicalKeyboardKey.goBack,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.gameButtonB,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _select(ResumeDialogResult result) {
    Navigator.of(context).pop(result);
  }

  void _moveFocus(int delta) {
    setState(() {
      _focusedIndex = (_focusedIndex + delta).clamp(0, _nodes.length - 1);
    });
    _nodes[_focusedIndex].requestFocus();
  }

  KeyEventResult _handleKey(int index, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (_kBackKeys.contains(key)) {
      _select(ResumeDialogResult.cancel);
      return KeyEventResult.handled;
    }

    if (_kEnterKeys.contains(key)) {
      if (index == 0) _select(ResumeDialogResult.resume);
      if (index == 1) _select(ResumeDialogResult.restart);
      if (index == 2) _select(ResumeDialogResult.cancel);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveFocus(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _moveFocus(1);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0D0D0D);
    const accentRed = Color(0xFFE50914);

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Continue watching?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Resume from where you left off or start over.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildButton(
                    index: 0,
                    label: 'Resume',
                    filled: true,
                    accentRed: accentRed,
                    onTap: () => _select(ResumeDialogResult.resume),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildButton(
                    index: 1,
                    label: 'Restart',
                    filled: false,
                    accentRed: accentRed,
                    onTap: () => _select(ResumeDialogResult.restart),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildButton(
                    index: 2,
                    label: 'Cancel',
                    filled: false,
                    accentRed: accentRed,
                    onTap: () => _select(ResumeDialogResult.cancel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required int index,
    required String label,
    required bool filled,
    required Color accentRed,
    required VoidCallback onTap,
  }) {
    final node = _nodes[index];
    return Focus(
      focusNode: node,
      onKeyEvent: (n, e) => _handleKey(index, n, e),
      child: AnimatedBuilder(
        animation: node,
        builder: (context, _) {
          final isFocused = node.hasFocus;
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled
                    ? accentRed
                    : Colors.white.withOpacity(isFocused ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFocused
                      ? Colors.white
                      : (filled ? accentRed : Colors.white.withOpacity(0.15)),
                  width: isFocused ? 2.2 : 1.0,
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
