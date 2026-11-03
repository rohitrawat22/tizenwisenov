// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';

import 'dart:ui' as ui;

import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/core/widgets/catch_up_picker_dialog.dart';
import 'package:wiseplayertizen/data/local_storage/hive_service.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';
import 'package:wiseplayertizen/data/models/fav.mode.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/get_playList_model.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/videos_on_particuler_channel_model.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/dashboard_sub_screen/show_playList_video.dart';

import '../../../core/widgets/cached_image.dart';

class ShowPlaylistVideoInListView extends StatefulWidget {
  final String urlTillChannel;
  bool? isMovies;
  bool isSeries;

  /// HotPlayer-speed optimisation C: when provided alongside [isLiveTv]=true,
  /// the widget constructs the live stream URL directly on tap instead of
  /// making an extra /api/live?streamId= round-trip.
  final String? playListId;
  final bool isLiveTv;

  ShowPlaylistVideoInListView({
    super.key,
    required this.urlTillChannel,
    this.isMovies = false,
    this.isSeries = false,
    this.playListId,
    this.isLiveTv = false,
  });

  @override
  State<ShowPlaylistVideoInListView> createState() =>
      _ShowPlaylistVideoInListViewState();
}

class _ShowPlaylistVideoInListViewState
    extends State<ShowPlaylistVideoInListView> {
  List<FavModel> favList = [];

  @override
  void initState() {
    super.initState();
    getFavData(); // ✅ called automatically by Flutter
  }

  Future<void> getFavData() async {
    final playlistId = widget.playListId ?? "";
    context.read<WiseBloc>().add(LoadFavoritesEvent(playlistId: playlistId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WiseBloc, WiseState>(
      buildWhen: (previous, current) =>
          previous.filterVideoOnParticulerChannelList !=
              current.filterVideoOnParticulerChannelList ||
          previous.selectedVideo != current.selectedVideo,

      // previous.videoOnParticulerChannelList !=
      //     current.videoOnParticulerChannelList,
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

        return videos.isEmpty
            ? Center(child: CText("Not Found"))
            : ListView.builder(
                itemExtent: 115, // O(1) scroll calculation
                itemCount: videos.length,

                itemBuilder: (context, index) {
                  VideosOnPerticulerChannelModel data = videos[index];
                  // bool isThisVideoWatching =
                  //     data.categoryId == state.selectedVideo?.categoryId;
                  bool isThisVideoWatching =
                      data.streamId == state.selectedVideo?.streamId;

                  return _ChannelListItem(
                    key: ValueKey(data.streamId),
                    data: data,
                    isThisVideoWatching: isThisVideoWatching,
                    urlTillChannel: widget.urlTillChannel,
                    playListId: widget.playListId,
                    isSeries: widget.isSeries,
                    isMovies: widget.isMovies ?? false,
                    onTap: () {
                      log("stream tap data is ----> is ${data.toJson()}");

                      // --- HotPlayer-speed optimisation C ---
                      bool usedDirectUrl = false;
                      if (widget.isLiveTv &&
                          widget.playListId != null &&
                          (int.parse(data.streamId.toString()) ?? 0) > 0) {
                        final playlist = state.playLists
                            .cast<GetplayListModel?>()
                            .firstWhere(
                              (p) => p?.id == widget.playListId,
                              orElse: () => null,
                            );
                        final serverUrl = playlist?.serverUrl ?? '';
                        final username = playlist?.username ?? '';
                        final password = playlist?.password ?? '';

                        if (serverUrl.isNotEmpty &&
                            username.isNotEmpty &&
                            password.isNotEmpty) {
                          final base = serverUrl.endsWith('/')
                              ? serverUrl.substring(0, serverUrl.length - 1)
                              : serverUrl;
                          const ext = 'm3u8';
                          final directUrl =
                              '$base/live/$username/$password/${data.streamId}.$ext';
                          log('🚀 [DirectURL] $directUrl');
                          BlocProvider.of<WiseBloc>(context).add(
                            SetDirectVideoUrlEvent(
                              videoUrl: directUrl,
                              selectedVideo: data,
                            ),
                          );
                          usedDirectUrl = true;
                        }
                      }

                      if (!usedDirectUrl) {
                        BlocProvider.of<WiseBloc>(context)
                            .add(SelectedVideoEvent(selectedVideo: data));
                        BlocProvider.of<WiseBloc>(context).add(
                          GetVideoUrlEvent(
                            channelId:
                                state.selectedChannel?.categoryId.toString() ??
                                "",
                            streamId: data.streamId.toString(),
                            urlTillChannel: widget.urlTillChannel,
                            extension: data.containerExtension,
                          ),
                        );
                      }
                    },
                  );

                  // Container(
                  //   width: 130,

                  //   decoration: BoxDecoration(
                  //     color: AppColor.darkBlue,
                  //     borderRadius: BorderRadius.circular(8),
                  //     // image: DecorationImage(
                  //     //   image: CachedNetworkImageProvider(data.streamIcon ?? ""),
                  //     // ),
                  //   ),
                  //   child: Stack(
                  //     children: [
                  //       // Positioned(
                  //       //   left: 2,
                  //       //   top: 2,
                  //       //   child: Container(
                  //       //     padding: EdgeInsets.all(2),
                  //       //     decoration: BoxDecoration(
                  //       //       color: AppColor.background,
                  //       //       borderRadius: BorderRadius.only(
                  //       //         topLeft: Radius.circular(6),
                  //       //         bottomRight: Radius.circular(6),
                  //       //       ),
                  //       //     ),
                  //       //     child: CText("⭐ $index", fontSize: 10),
                  //       //   ),
                  //       // ),
                  //       Positioned(
                  //         bottom: 0,
                  //         left: 0,
                  //         right: 0,
                  //         child: Container(
                  //           padding: EdgeInsets.only(left: 5, right: 5),
                  //           height: 50,
                  //           color: const Color.fromARGB(221, 0, 0, 0),
                  //           child: Column(
                  //             children: [
                  //               CText(
                  //                 maxLines: 2,
                  //                 data.name ?? "N/A",
                  //                 fontSize: 12,
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       ),
                  //       Positioned(
                  //         right: 0,
                  //         top: 0,
                  //         left: 0,
                  //         bottom: 50,
                  //         child: InkWell(
                  //           onTap: () {
                  //             playVideoInfoData = data;
                  //             log(
                  //               "stream tap data is ----> is ${data.toJson()}",
                  //             );
                  //             BlocProvider.of<WiseBloc>(context).add(
                  //               GetVideoUrlEvent(
                  //                 channelId: gChannelId,

                  //                 streamId: data.streamId.toString(),
                  //                 urlTillChannel: widget.urlTillChannel,
                  //               ),
                  //             );
                  //             // if (state.status == Status.success &&
                  //             //     state.videoUrl.isNotEmpty) {
                  //             //   GoRouter.of(context).push(
                  //             //     VideoPlayerScreen.routeName,
                  //             //     extra: state.videoUrl, // pass url
                  //             //   );
                  //             // }
                  //             // Future.delayed(Duration(seconds: 3), () {
                  //             //   // stopLoader(context);
                  //             //   GoRouter.of(
                  //             //     context,
                  //             //   ).push(VideoPlayerScreen.routeName);
                  //             // });
                  //             // log("video url print ${state.videoUrl}");
                  //           },
                  //           child: CachedImage(
                  //             // fit: widget.isMovies! || widget.isSeries!
                  //             //     ? BoxFit.fill
                  //             //     : BoxFit.f,
                  //             fit: BoxFit.fitWidth,
                  //             imageUrl: data.streamIcon,

                  //             height: double.infinity,
                  //             width: double.infinity,
                  //           ),
                  //         ),
                  //       ),
                  //       Positioned(
                  //         right: 2,
                  //         top: 2,
                  //         child: Container(
                  //           decoration: BoxDecoration(
                  //             color: AppColor.background,
                  //             borderRadius: BorderRadius.only(
                  //               topRight: Radius.circular(10),
                  //               bottomLeft: Radius.circular(10),
                  //             ),
                  //           ),
                  //           child: Icon(Icons.favorite_border),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // );
                },
              );
      },
    );
  }

  bool isFav(String streamId) {
    return context.read<WiseBloc>().state.favorites.any(
      (fav) => fav.id == streamId,
    );
  }
}

class _FavButton extends StatelessWidget {
  final VideosOnPerticulerChannelModel data;
  final String? playListId;
  final String urlTillChannel;
  final bool isSeries;
  final bool isMovies;

  const _FavButton({
    required this.data,
    required this.playListId,
    required this.urlTillChannel,
    required this.isSeries,
    required this.isMovies,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WiseBloc, WiseState>(
      buildWhen: (p, c) => p.favorites != c.favorites,
      builder: (context, state) {
        final isFav = state.favorites.any(
          (fav) => fav.id == data.streamId.toString(),
        );

        return IconButton(
          onPressed: () {
            final playlistId = playListId ?? "";
            final isLive = isSeries == false && isMovies == false;
            final streamType = isLive ? 'LIVE' : (isSeries ? 'SERIES' : 'VOD');

            if (isFav) {
              context.read<WiseBloc>().add(
                RemoveFavoriteEvent(
                  playlistId: playlistId,
                  streamId: data.streamId.toString(),
                  streamType: streamType,
                ),
              );
            } else {
              context.read<WiseBloc>().add(
                AddFavoriteEvent(
                  playlistId: playlistId,
                  streamId: data.streamId.toString(),
                  streamType: streamType,
                  name: data.name ?? "N/A",
                  streamIcon: data.streamIcon ?? "",
                ),
              );
            }
          },
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? AppColor.coralRed : Colors.white.withOpacity(0.5),
            size: 26,
          ),
        );
      },
    );
  }
}

class _CatchUpButton extends StatelessWidget {
  final VideosOnPerticulerChannelModel data;
  final String urlTillChannel;

  const _CatchUpButton({required this.data, required this.urlTillChannel});

  Future<void> _openCatchUp(BuildContext context) async {
    final selection = await showCatchUpPickerDialog(
      context,
      channelName: data.name ?? 'this channel',
      archiveDays: data.tvArchiveDuration ?? 0,
    );
    if (selection == null || !context.mounted) return;
    BlocProvider.of<WiseBloc>(context)
        .add(SelectedVideoEvent(selectedVideo: data));
    BlocProvider.of<WiseBloc>(context).add(
      GetTimeshiftUrlEvent(
        urlTillChannel: urlTillChannel,
        streamId: data.streamId.toString(),
        timestamp: selection.timestamp,
        duration: selection.durationMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _openCatchUp(context),
      icon: const Icon(
        Icons.history_rounded,
        color: Color(0xFF4DD0E1),
        size: 26,
      ),
    );
  }
}

class _ChannelListItem extends StatelessWidget {
  final VideosOnPerticulerChannelModel data;
  final bool isThisVideoWatching;
  final VoidCallback onTap;
  final String urlTillChannel;
  final String? playListId;
  final bool isSeries;
  final bool isMovies;

  const _ChannelListItem({
    super.key,
    required this.data,
    required this.isThisVideoWatching,
    required this.onTap,
    required this.urlTillChannel,
    required this.playListId,
    required this.isSeries,
    required this.isMovies,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isThisVideoWatching
            ? [
                BoxShadow(
                  color: AppColor.coralRed.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
        color: isThisVideoWatching
            ? AppColor.coralRed.withOpacity(0.75)
            : const Color(0xFF1A1A2E),
        border: Border.all(
          color: isThisVideoWatching
              ? Colors.white.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedImage(
                        fit: BoxFit.cover,
                        imageUrl: data.streamIcon,
                        width: double.infinity,
                        height: 80,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CText(
                          maxLines: 2,
                          data.name ?? "N/A",
                          fontSize: 15,
                          fontWeight: isThisVideoWatching
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isThisVideoWatching
                              ? Colors.white
                              : Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: CText(
                            maxLines: 1,
                            "ID: ${data.streamId}",
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data.isCatchUpEnabled)
                    _CatchUpButton(data: data, urlTillChannel: urlTillChannel),
                  _FavButton(
                    data: data,
                    playListId: playListId,
                    urlTillChannel: urlTillChannel,
                    isSeries: isSeries,
                    isMovies: isMovies,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
