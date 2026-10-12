// // import 'dart:developer';
// // import 'package:better_player_plus/better_player_plus.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:flutter_bloc/flutter_bloc.dart';
// // import 'package:wiseplayertizen/core/widgets/custom_text.dart';
// // import '../../../core/utils/get_dymention.dart';
// // import '../../../core/utils/loader.dart';
// // import '../../../core/utils/message_dialog.dart';
// // import '../../../core/utils/snackbar.dart';
// // import '../../../core/widgets/custom_textFormFiled.dart';
// // import '../bloc/model/videos_on_particuler_channel_model.dart';
// // import '../bloc/wise_bloc.dart';
// // import '../common/dashboard_sub_screen/channels.dart';
// // import 'show_playList_video_in_listview.dart';
// // import '../../../core/routes/routes_path.dart';

// // class MoblieDashboardScreen extends StatefulWidget {
// //   static const String routeName = AppRoutes.mobileDashboard;
// //   final String playListId;
// //   final bool isLiveTv;
// //   final bool isMovies;
// //   final bool isSeries;
// //   final bool isRadio;

// //   const MoblieDashboardScreen({
// //     super.key,
// //     required this.playListId,
// //     required this.isLiveTv,
// //     required this.isMovies,
// //     required this.isSeries,
// //     required this.isRadio,
// //   });

// //   @override
// //   State<MoblieDashboardScreen> createState() => _MoblieDashboardScreenState();
// // }

// // class _MoblieDashboardScreenState extends State<MoblieDashboardScreen> {
// //   String finalUrl = "";
// //   String? _currentlyPlayingUrl;
// //   TextEditingController searchCtrl = TextEditingController();
// //   bool isSearching = false;
// //   BetterPlayerController? _controller;
// //   bool _isPlayerReady = false;
// //   bool _isInitializing = false;
// //   bool _isLoaderShowing = false; // Track loader state to prevent screen pop

// //   @override
// //   void initState() {
// //     super.initState();
// //     // Reset state immediately on entry to clear old flags
// //     Future.microtask(() {
// //       context.read<WiseBloc>().add(ResetVideoUrlEvent());
// //       _getData();
// //     });
// //   }

// //   void _safeStopLoader() {
// //     if (_isLoaderShowing) {
// //       stopLoader(context);
// //       _isLoaderShowing = false;
// //     }
// //   }

// //   void _safeShowLoader() {
// //     if (!_isLoaderShowing) {
// //       loader(context);
// //       _isLoaderShowing = true;
// //     }
// //   }

// //   @override
// //   void dispose() {
// //     SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
// //     _controller?.dispose();
// //     searchCtrl.dispose();
// //     super.dispose();
// //   }

// //   Future<void> _getData() async {
// //     String url = "";
// //     if (widget.isLiveTv) {
// //       url = "/api/live?playlistId=${widget.playListId}";
// //     } else if (widget.isMovies) {
// //       url = "/api/movie?playlistId=${widget.playListId}";
// //     } else if (widget.isSeries) {
// //       url = "/api/series?playlistId=${widget.playListId}";
// //     } else {
// //       url = "/api/live?playlistId=${widget.playListId}";
// //     }
// //     finalUrl = url;
// //     context.read<WiseBloc>().add(ChannelEvent(url: url));
// //   }

// //   Future<void> getVideoData({required String videoUrl}) async {
// //     if (_isInitializing || _currentlyPlayingUrl == videoUrl) return;

// //     setState(() {
// //       _isInitializing = true;
// //       _isPlayerReady = false;
// //     });

// //     try {
// //       if (_controller != null) {
// //         _controller!.dispose();
// //         _controller = null;
// //       }

// //       _currentlyPlayingUrl = videoUrl;

// //       // Detect format (.ts or .m3u8)
// //       BetterPlayerVideoFormat format = BetterPlayerVideoFormat.other;
// //       if (videoUrl.toLowerCase().contains(".m3u8")) {
// //         format = BetterPlayerVideoFormat.hls;
// //       }

// //       final dataSource = BetterPlayerDataSource(
// //         BetterPlayerDataSourceType.network,
// //         videoUrl,
// //         liveStream: widget.isLiveTv,
// //         videoFormat: format,
// //         headers: {"User-Agent": "Mozilla/5.0"},
// //       );

// //       _controller = BetterPlayerController(
// //         BetterPlayerConfiguration(
// //           autoPlay: true,
// //           aspectRatio: 16 / 9,
// //           fit: BoxFit.contain,
// //           handleLifecycle: true,
// //           controlsConfiguration: BetterPlayerControlsConfiguration(
// //             enableProgressBar: !widget.isLiveTv,
// //             enableSkips: !widget.isLiveTv,
// //             showControls: true,
// //           ),
// //         ),
// //         betterPlayerDataSource: dataSource,
// //       );

// //       setState(() => _isPlayerReady = true);
// //     } catch (e) {
// //       log("Player Error: $e");
// //     } finally {
// //       if (mounted) setState(() => _isInitializing = false);
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         leading: IconButton(
// //           icon: const Icon(Icons.arrow_back_ios_new),
// //           onPressed: () => Navigator.pop(context),
// //         ),
// //         title: isSearching
// //             ? SizedBox(
// //                 height: 45,
// //                 child: CustomTextFormFiled(
// //                   isOnChanged: true,
// //                   onChanged: (newValue) {
// //                     context.read<WiseBloc>().add(
// //                       FilterVideosOnPerticulerChannelEvent(
// //                         searchText: newValue,
// //                         isSearchChannelOnTextField: false,
// //                       ),
// //                     );
// //                   },
// //                   controller: searchCtrl,
// //                   hintText: "Search video...",
// //                   suffixIcon: IconButton(
// //                     icon: const Icon(Icons.close),
// //                     onPressed: () {
// //                       setState(() => isSearching = false);
// //                       searchCtrl.clear();
// //                       context.read<WiseBloc>().add(
// //                         FilterVideosOnPerticulerChannelEvent(
// //                           searchText: "",
// //                           isSearchChannelOnTextField: false,
// //                         ),
// //                       );
// //                     },
// //                   ),
// //                 ),
// //               )
// //             : Text(widget.isLiveTv ? "Live TV" : "Movies/Series"),
// //         actions: [
// //           if (!isSearching)
// //             IconButton(
// //               onPressed: () => setState(() => isSearching = true),
// //               icon: const Icon(Icons.search),
// //             ),
// //           Builder(
// //             builder: (context) => IconButton(
// //               onPressed: () => Scaffold.of(context).openDrawer(),
// //               icon: const Icon(Icons.menu_open_rounded),
// //             ),
// //           ),
// //         ],
// //       ),
// //       drawer: Drawer(
// //         child: Column(
// //           children: [
// //             DrawerHeader(
// //               decoration: BoxDecoration(color: Theme.of(context).primaryColor),
// //               child: Center(
// //                 child: IconButton(
// //                   onPressed: () => debugPrint("😀😀😀${finalUrl}"),
// //                   icon: Icon(Icons.tv_rounded, size: 80, color: Colors.white),
// //                 ),
// //               ),
// //             ),
// //             Expanded(
// //               child: Channels(urlTillChannel: finalUrl, isForMobile: true),
// //             ),
// //           ],
// //         ),
// //       ),
// //       body: BlocConsumer<WiseBloc, WiseState>(
// //         listener: (context, state) {
// //           if (state.status == Status.loading) {
// //             _safeShowLoader();
// //           } else if (state.status == Status.error) {
// //             _safeStopLoader();
// //             messageDialog(
// //               title: const Text("Error"),
// //               content: Text(state.errorMessage),
// //               context: context,
// //               onTap: () => Navigator.pop(context),
// //               okk: "OK",
// //             );
// //           } else if (state.status == Status.success) {
// //             if (state.isStopLoader) _safeStopLoader();
// //             if (state.videoUrl.isNotEmpty && state.isVideoLoaded) {
// //               getVideoData(videoUrl: state.videoUrl);
// //             }
// //           }
// //         },
// //         builder: (context, state) {
// //           return Column(
// //             children: [
// //               RepaintBoundary(
// //                 child: AspectRatio(
// //                   aspectRatio: 16 / 9,
// //                   child: Container(
// //                     color: Colors.black,
// //                     child: _isPlayerReady && _controller != null
// //                         ? BetterPlayer(controller: _controller!)
// //                         : const Center(
// //                             child: CircularProgressIndicator(
// //                               color: Colors.white,
// //                             ),
// //                           ),
// //                   ),
// //                 ),
// //               ),
// //               const SizedBox(height: 5),
// //               Expanded(
// //                 child:
// //                     state.filterVideoOnParticulerChannelList.isEmpty &&
// //                         !isSearching
// //                     ? Center(child: CText("Open menu to select a category"))
// //                     : ShowPlaylistVideoInListView(
// //                         urlTillChannel: finalUrl,
// //                         isMovies: widget.isMovies,
// //                         isSeries: widget.isSeries,
// //                       ),
// //               ),
// //             ],
// //           );
// //         },
// //       ),
// //     );
// //   }
// // }
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:wiseplayertizen/core/colors/colors.dart';
// import 'package:wiseplayertizen/core/widgets/custom_text.dart';
// import 'package:wiseplayertizen/presentation/screen_view/bloc/model/channel_model.dart';
// import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';

// String gChannelId = "";

// class Channels extends StatefulWidget {
//   final bool isForMobile;
//   final String urlTillChannel;
//   const Channels({
//     super.key,
//     required this.urlTillChannel,
//     this.isForMobile = false,
//   });

//   @override
//   State<Channels> createState() => _ChannelsState();
// }

// class _ChannelsState extends State<Channels> {
//   final ScrollController _scrollController = ScrollController();

//   void goToSelectedChannel(int index) {
//     if (index < 0) return;
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       // Check if controller is attached to avoid crashes
//       if (_scrollController.hasClients) {
//         double position = (index * 70.0).toDouble();
//         _scrollController.animateTo(
//           position,
//           duration: const Duration(milliseconds: 500),
//           curve: Curves.easeInOut,
//         );
//       }
//     });
//   }

//   @override
//   void initState() {
//     super.initState();
//     final state = context.read<WiseBloc>().state;
//     if (state.filterChannelsList.isNotEmpty) {
//       int selectedIndex = state.filterChannelsList.indexWhere(
//         (e) => e.categoryId == state.selectedChannel?.categoryId,
//       );
//       goToSelectedChannel(selectedIndex);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return BlocConsumer<WiseBloc, WiseState>(
//       listener: (context, state) {
//         if (state.filterChannelsList.isNotEmpty) {
//           int selectedIndex = state.filterChannelsList.indexWhere(
//             (e) => e.categoryId == state.selectedChannel?.categoryId,
//           );
//           goToSelectedChannel(selectedIndex);
//         }
//       },
//       builder: (context, state) {
//         return state.filterChannelsList.isEmpty
//             ? Center(child: CText("No Categories Found", color: Colors.grey))
//             : ListView.builder(
//                 controller: _scrollController,
//                 padding: const EdgeInsets.symmetric(vertical: 10),
//                 itemCount: state.filterChannelsList.length,
//                 itemBuilder: (context, index) {
//                   ChannelModel data = state.filterChannelsList[index];
//                   bool isSelected =
//                       state.selectedChannel?.categoryId == data.categoryId;

//                   return SizedBox(
//                     height: 70,
//                     child: Card(
//                       margin: const EdgeInsets.symmetric(
//                         horizontal: 10,
//                         vertical: 4,
//                       ),
//                       elevation: isSelected ? 4 : 1,
//                       color: isSelected ? AppColor.coralRed : null,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: ListTile(
//                         onTap: () {
//                           // 1. Close the drawer first for a smooth transition
//                           Navigator.of(context).pop();

//                           // 2. Only trigger update if category is different
//                           if (state.selectedChannel?.categoryId !=
//                               data.categoryId) {
//                             gChannelId = data.categoryId ?? "";
//                             final bloc = context.read<WiseBloc>();

//                             bloc.add(
//                               VideosOnPerticulerChannelEvent(
//                                 channelId: data.categoryId!,
//                                 urlTillChannel: widget.urlTillChannel,
//                                 isStopLoader: false,
//                               ),
//                             );
//                             debugPrint(
//                               "😀😀😀😀selected channel id in channel screen ${data.categoryId}",
//                             );
//                             debugPrint(
//                               "😀😀😀😀selected  screen ${widget.urlTillChannel}",
//                             );

//                             // Set this as the selected category
//                             bloc.add(
//                               SelectedChannelEvent(selectedChannel: data),
//                             );
//                           }
//                         },
//                         title: CText(
//                           data.categoryName ?? "N/A",
//                           maxLines: 1,
//                           //color: isSelected ? Colors.white : null,
//                           fontWeight: isSelected
//                               ? FontWeight.bold
//                               : FontWeight.normal,
//                         ),
//                         leading: Icon(
//                           Icons.folder_open_rounded,
//                           color: isSelected ? Colors.white : AppColor.coralRed,
//                         ),
//                         trailing: isSelected
//                             ? const Icon(
//                                 Icons.check_circle,
//                                 color: Colors.white,
//                                 size: 20,
//                               )
//                             : const Icon(Icons.arrow_forward_ios, size: 14),
//                       ),
//                     ),
//                   );
//                 },
//               );
//       },
//     );
//   }
// }
