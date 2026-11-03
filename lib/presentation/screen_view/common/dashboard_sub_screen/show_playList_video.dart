import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';
import 'package:wiseplayertizen/core/widgets/catch_up_picker_dialog.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/get_playList_model.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/videos_on_particuler_channel_model.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/data/local_storage/hive_service.dart';
import 'package:wiseplayertizen/data/models/fav.mode.dart';
import 'package:wiseplayertizen/series/serie.details.dart';

import '../../../../core/widgets/cached_image.dart';
import 'channels.dart';

class ShowPlaylistVideoInGrid extends StatefulWidget {
  final String urlTillChannel;
  final String playListId;
  final String seriesID;
  final bool? isMovies;
  final bool isSeries;
  final TextEditingController? streamSearchCtrl;

  const ShowPlaylistVideoInGrid({
    super.key,
    required this.urlTillChannel,
    required this.playListId,
    required this.seriesID,
    this.isMovies = false,
    this.isSeries = false,
    this.streamSearchCtrl,
  });

  @override
  State<ShowPlaylistVideoInGrid> createState() =>
      _ShowPlaylistVideoInGridState();
}

class _ShowPlaylistVideoInGridState extends State<ShowPlaylistVideoInGrid> {
  // FocusNodes are now owned by _StreamCardState so they are disposed
  // automatically when a card scrolls out of view (RepaintBoundary keeps
  // element alive only while visible). Previously the parent cached ALL
  // nodes in a Map that grew forever, causing OOM on large playlists.

  @override
  void initState() {
    super.initState();
    widget.streamSearchCtrl?.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(ShowPlaylistVideoInGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamSearchCtrl != widget.streamSearchCtrl) {
      oldWidget.streamSearchCtrl?.removeListener(_onSearchChanged);
      widget.streamSearchCtrl?.addListener(_onSearchChanged);
    }
  }

  @override
  void dispose() {
    widget.streamSearchCtrl?.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    final state = context.read<WiseBloc>().state;
    if (state.selectedChannel?.categoryId == 'favorites_category') {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WiseBloc, WiseState>(
      buildWhen: (previous, current) =>
          previous.filterVideoOnParticulerChannelList !=
              current.filterVideoOnParticulerChannelList ||
          previous.selectedChannel?.categoryId !=
              current.selectedChannel?.categoryId,
      builder: (context, state) {
        List<VideosOnPerticulerChannelModel> videos =
            state.selectedChannel?.categoryId == 'favorites_category'
            ? state.favorites
                  .map(
                    (fav) => VideosOnPerticulerChannelModel(
                      streamId: fav.id,
                      name: fav.title,
                      streamIcon: fav.photoImage,
                      streamType: fav.streamType,
                      categoryId: fav.playlistId,
                      containerExtension: fav.containerExtension,
                    ),
                  )
                  .toList()
            : state.filterVideoOnParticulerChannelList;

        if (state.selectedChannel?.categoryId == 'favorites_category' &&
            widget.streamSearchCtrl != null &&
            widget.streamSearchCtrl!.text.isNotEmpty) {
          final query = widget.streamSearchCtrl!.text.toLowerCase();
          videos = videos
              .where(
                (v) =>
                    (v.name?.toLowerCase().contains(query) ?? false) ||
                    (v.streamId?.toString().toLowerCase().contains(query) ??
                        false),
              )
              .toList();
        }

        if (videos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  color: Colors.white24,
                  size: 56,
                ),
                SizedBox(height: 12),
                CText('No streams found', color: Colors.white38, fontSize: 16),
              ],
            ),
          );
        }

        return GridView.builder(
          cacheExtent: 1200, // PERF: keep ~7 rows ahead in memory to prevent jank on fast scroll
          padding: const EdgeInsets.all(10),
          itemCount: videos.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            maxCrossAxisExtent: 110,
            childAspectRatio: 0.65,
          ),
          itemBuilder: (context, index) {
            final data = videos[index];
            DateTime? lastTapTime;

            void handlePlay() {
              if (lastTapTime != null &&
                  DateTime.now().difference(lastTapTime!).inMilliseconds <
                      1000) {
                return; // Debounce rapid double-clicks
              }
              lastTapTime = DateTime.now();

              log('stream tap data is ------> ${data..toString()}');
              if (state.status != Status.loading && !widget.isSeries) {
                // Clear stale videoUrl/isVideoLoaded from the previous channel.
                // Without this, the BlocListener fires on SelectedVideoEvent
                // (success + old videoUrl still in state) causing double-navigation.
                BlocProvider.of<WiseBloc>(context).add(ResetVideoUrlEvent());
                BlocProvider.of<WiseBloc>(context)
                    .add(SelectedVideoEvent(selectedVideo: data));
                BlocProvider.of<WiseBloc>(context).add(
                  GetVideoUrlEvent(
                    channelId:
                        data.categoryId ??
                        state.selectedChannel?.categoryId ??
                        "",
                    streamId: data.streamId.toString(),
                    urlTillChannel: widget.urlTillChannel,
                    extension: data.containerExtension,
                  ),
                );
              } else if (state.status != Status.loading &&
                  widget.isSeries == true) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeriesDetailScreen(
                      playlistId: widget.playListId,
                      seriesId: data.streamId.toString() ?? "",
                      baseUrl: "https://api.wise-player.com/",
                    ),
                  ),
                );
              } else {
                log("sdfsdfsdfsd");
              }
            }

            return _StreamCard(
              data: data,
              urlTillChannel: widget.urlTillChannel,
              playListId: widget.playListId,
              isMovies: widget.isMovies,
              isSeries: widget.isSeries,
              onPlay: handlePlay,
              onCatchUp: () async {
                if (state.status != Status.loading) {
                  final selection = await showCatchUpPickerDialog(
                    context,
                    channelName: data.name ?? 'this channel',
                    archiveDays: data.tvArchiveDuration ?? 0,
                  );
                  if (selection == null || !mounted) return;
                  final bloc = BlocProvider.of<WiseBloc>(this.context);
                  bloc.add(SelectedVideoEvent(selectedVideo: data));
                  bloc.add(
                    GetTimeshiftUrlEvent(
                      urlTillChannel: widget.urlTillChannel,
                      streamId: data.streamId.toString(),
                      timestamp: selection.timestamp,
                      duration: selection.durationMinutes,
                    ),
                  );
                }
              },
              onFavToggle: () {
                if (mounted) setState(() {});
              },
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single stream card — stateful so fav state updates independently
// ---------------------------------------------------------------------------
class _StreamCard extends StatefulWidget {
  final VideosOnPerticulerChannelModel data;
  final String urlTillChannel;
  final String playListId;
  final bool? isMovies;
  final bool isSeries;
  final VoidCallback onPlay;
  final VoidCallback onCatchUp;
  final VoidCallback onFavToggle;

  const _StreamCard({
    required this.data,
    required this.urlTillChannel,
    required this.playListId,
    required this.isMovies,
    required this.isSeries,
    required this.onPlay,
    required this.onCatchUp,
    required this.onFavToggle,
  });

  @override
  State<_StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<_StreamCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // FocusNodes live here so they are disposed when the card scrolls off-screen.
  final FocusNode _cardNode = FocusNode(debugLabel: 'stream_card');
  final FocusNode _catchUpNode = FocusNode(debugLabel: 'stream_catchup');
  final FocusNode _favNode = FocusNode(debugLabel: 'stream_fav');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    // Wire D-pad navigation between the three focus targets on this card.
    _rewireNodes();

    _cardNode.addListener(_rebuild);
    _catchUpNode.addListener(_rebuild);
    _favNode.addListener(_rebuild);
  }

  void _rewireNodes() {
    final hasCatchUp = widget.data.isCatchUpEnabled;
    wireDpadNode(
      _cardNode,
      right: hasCatchUp ? _catchUpNode : _favNode,
      onSelect: widget.onPlay,
    );
    wireDpadNode(_catchUpNode, left: _cardNode, right: _favNode);
    wireDpadNode(_favNode, left: hasCatchUp ? _catchUpNode : _cardNode);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cardNode.removeListener(_rebuild);
    _catchUpNode.removeListener(_rebuild);
    _favNode.removeListener(_rebuild);
    // Dispose nodes here — they are no longer referenced by anything else.
    _cardNode.dispose();
    _catchUpNode.dispose();
    _favNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleFav() async {
    _pulseController.forward(from: 0);
    final playlistId = widget.playListId;
    final isLive = widget.isMovies == false && widget.isSeries == false;
    final streamType = isLive ? 'LIVE' : (widget.isSeries ? 'SERIES' : 'VOD');

    final isFav = context.read<WiseBloc>().state.favorites.any(
      (f) => f.id == widget.data.streamId.toString(),
    );

    if (isFav) {
      context.read<WiseBloc>().add(
        RemoveFavoriteEvent(
          playlistId: playlistId,
          streamId: widget.data.streamId.toString(),
          streamType: streamType,
        ),
      );
    } else {
      context.read<WiseBloc>().add(
        AddFavoriteEvent(
          playlistId: playlistId,
          streamId: widget.data.streamId.toString(),
          streamType: streamType,
          name: widget.data.name,
          streamIcon: widget.data.streamIcon,
        ),
      );
    }
    widget.onFavToggle();
  }

  @override
  Widget build(BuildContext context) {
    final isFav = context.watch<WiseBloc>().state.favorites.any(
      (f) => f.id == widget.data.streamId.toString(),
    );
    final isCardFocused = _cardNode.hasFocus;
    final isCatchUpFocused = _catchUpNode.hasFocus;
    final isFavFocused = _favNode.hasFocus;
    final isAnyFocused = isCardFocused || isCatchUpFocused || isFavFocused;
    final showCatchUp = widget.data.isCatchUpEnabled;

    // PERF: collapsed AnimatedScale + AnimatedContainer into a single
    // AnimatedContainer with a Matrix4 scale transform. Halves the widget-tree
    // depth for every card and avoids two separate animation ticks per frame.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      transform: Matrix4.identity()..scale(isAnyFocused ? 1.06 : 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColor.darkBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCardFocused
              ? Colors.white
              : (isFavFocused ? AppColor.accentRed : AppColor.whiteOpacity08),
          width: isAnyFocused ? 2.5 : 1.0,
        ),
        // PERF: BoxShadow only when card is focused — idle cards had a
        // blurred shadow painting on every frame for zero visual benefit.
        boxShadow: isAnyFocused
            ? [
                BoxShadow(
                  color: (isCardFocused
                      ? Colors.white
                      : AppColor.accentRedOpacity30),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // ── Thumbnail + Play tap area ──────────────────────────────
            Positioned.fill(
              child: InkWell(
                focusNode: _cardNode,
                borderRadius: BorderRadius.circular(14),
                onTap: widget.onPlay,
                child: Stack(
                  children: [
                    // Thumbnail
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 54,
                      child: CachedImage(
                        fit: BoxFit.cover,
                        imageUrl: widget.data.streamIcon,
                        height: double.infinity,
                        width: double.infinity,
                      ),
                    ),

                    // Play overlay when card is focused
                    if (isCardFocused)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 54,
                        child: Container(
                          color: AppColor.blackOpacity40,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),
                      ),

                    // Title bar at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 54,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColor.blackOpacity95,
                              AppColor.blackOpacity75,
                            ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                        child: CText(
                          widget.data.name ?? 'N/A',
                          maxLines: 2,
                          fontSize: 11,
                          color: isCardFocused ? Colors.white : Colors.white70,
                          fontWeight: isCardFocused
                              ? FontWeight.bold
                              : FontWeight.normal,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Catch-up button (only for archive-enabled channels) ──
            if (showCatchUp)
              Positioned(
                top: 6,
                left: 6,
                child: _buildCatchUpButton(isCatchUpFocused),
              ),

            // ── Favourite button ───────────────────────────────────────
            Positioned(
              top: 6,
              right: 6,
              child: _buildFavButton(isFavFocused, isFav),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavButton(bool isFavFocused, bool isFav) {
    return GestureDetector(
      onTap: _toggleFav,
      child: Focus(
        focusNode: _favNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            _toggleFav();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isFavFocused ? 10 : 6,
            vertical: isFavFocused ? 6 : 5,
          ),
          decoration: BoxDecoration(
            gradient: isFavFocused
                ? LinearGradient(
                    colors: [
                      AppColor.accentRed,
                      AppColor.accentRed.withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFavFocused
                  ? Colors.white
                  : (isFav
                        ? AppColor.accentRed.withOpacity(0.7)
                        : Colors.white24),
              width: isFavFocused ? 2.0 : 1.0,
            ),
            boxShadow: isFavFocused
                ? [
                    BoxShadow(
                      color: AppColor.accentRed.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : (isFav
                      ? [
                          BoxShadow(
                            color: AppColor.accentRed.withOpacity(0.25),
                            blurRadius: 6,
                          ),
                        ]
                      : []),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav
                      ? (isFavFocused ? Colors.white : AppColor.accentRed)
                      : Colors.white70,
                  size: isFavFocused ? 24 : 20,
                ),
              ),
              if (isFavFocused) ...[
                const SizedBox(width: 5),
                Text(
                  isFav ? 'Saved' : 'Save',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatchUpButton(bool isCatchUpFocused) {
    return GestureDetector(
      onTap: widget.onCatchUp,
      child: Focus(
        focusNode: _catchUpNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                  event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
            widget.onCatchUp();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isCatchUpFocused ? 10 : 6,
            vertical: isCatchUpFocused ? 6 : 5,
          ),
          decoration: BoxDecoration(
            gradient: isCatchUpFocused
                ? LinearGradient(
                    colors: [const Color(0xFF00BCD4), const Color(0xFF0097A7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCatchUpFocused
                  ? Colors.white
                  : const Color(0xFF00BCD4).withOpacity(0.6),
              width: isCatchUpFocused ? 2.0 : 1.0,
            ),
            boxShadow: isCatchUpFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF00BCD4).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                color: isCatchUpFocused
                    ? Colors.white
                    : const Color(0xFF4DD0E1),
                size: isCatchUpFocused ? 24 : 20,
              ),
              if (isCatchUpFocused) ...[
                const SizedBox(width: 5),
                Text(
                  'Catch-up',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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
