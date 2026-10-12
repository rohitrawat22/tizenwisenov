// import 'dart:developer';

// import 'package:better_player_plus/better_player_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:go_router/go_router.dart';
// import 'package:wiseplayertizen/core/colors/colors.dart';
// import 'package:wiseplayertizen/core/const/api/onboardingApi.dart';
// import 'package:wiseplayertizen/core/utils/alert_dialog.dart';
// import 'package:wiseplayertizen/core/widgets/custom_text.dart';
// import 'package:wiseplayertizen/presentation/screen_view/bloc/model/videos_on_particuler_channel_model.dart';
// import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';

// import '../../../../core/routes/routes_path.dart';
// import '../../../../core/utils/app_logo.dart';

// class VideoPlayerScreenForMoblie extends StatefulWidget {
//   final String videoUrl;
//   final VideosOnPerticulerChannelModel videoInfo;
//   static const routeName = AppRoutes.videoPlayer;

//   VideoPlayerScreenForMoblie({
//     super.key,
//     required this.videoUrl,
//     required this.videoInfo,
//   });

//   @override
//   State<VideoPlayerScreenForMoblie> createState() =>
//       _VideoPlayerScreenForMoblieState();
// }

// class _VideoPlayerScreenForMoblieState
//     extends State<VideoPlayerScreenForMoblie> {
//   late BetterPlayerController _controller;
//   bool _isPlayerReady = false;

//   @override
//   void initState() {
//     super.initState();
//     getData();
//   }

//   // @override
//   // void didChangeDependencies() {
//   //   super.didChangeDependencies();
//   //   log("didChangeDependencies calling ... in videoplayer");
//   //   // BlocProvider.of<WiseBloc>(context).add(ResetVideoUrlEvent());
//   // }

//   getData() {
//     log(
//       "your data comes form previous screen in vidOPyler mobile is ${widget.videoUrl} and data= ${widget.videoInfo.toJson()}",
//     );
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     // BlocProvider.of<WiseBloc>(context).add(ResetVideoUrlEvent());

//     // log("video url in vedioPlayer screen is ${state.videoUrl}");

//     final dataSource = BetterPlayerDataSource(
//       BetterPlayerDataSourceType.network,

//       // widget.videoUrl,

//       // 'https://line.vpnworld.pro/live/27C4CD/47C102/1444570.ts',
//       widget.videoUrl,
//       liveStream: true,

//       bufferingConfiguration: const BetterPlayerBufferingConfiguration(
//         minBufferMs: 10000,
//         maxBufferMs: 60000,
//         bufferForPlaybackMs: 2000,
//         bufferForPlaybackAfterRebufferMs: 3000,
//       ),
//     );
//     // static const defaultMinBufferMs = 25000;
//     // static const defaultMaxBufferMs = 6553600;
//     // static const defaultBufferForPlaybackMs = 3000;
//     // static const defaultBufferForPlaybackAfterRebufferMs = 6000;
//     // liveStream: true,  // enable this if it's IPTV live stream

//     // "http://90758-haven.dn-4kott.com/live/59226c0a3a/1778f6574830/845442.ts",

//     _controller = BetterPlayerController(
//       const BetterPlayerConfiguration(
//         autoPlay: true,
//         aspectRatio: 16 / 9,
//         fit: BoxFit.contain,
//         autoDetectFullscreenDeviceOrientation: true,
//         fullScreenByDefault: false,

//         controlsConfiguration: BetterPlayerControlsConfiguration(
//           enableSubtitles: true,
//           enableAudioTracks: true,
//         ),
//       ),
//       betterPlayerDataSource: dataSource,
//     );

//     // }
//     _isPlayerReady = true;
//     setState(() {});
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     _controller.dispose(); // very important
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//   }

//   @override
//   Widget build(BuildContext context) {
//     log("mobile player callingg.....");
//     return AspectRatio(
//       aspectRatio: 16 / 9,
//       child: BetterPlayer(controller: _controller),
//     );

//     // appBar: AppBar(title: appLogo(), centerTitle: true),
//     // body: BlocBuilder<WiseBloc, WiseState>(
//     //   builder: (context, state) {
//     //     return Column(
//     //       children: [
//     //         Column(
//     //           children: [
//     //             AspectRatio(
//     //               aspectRatio: 16 / 9,
//     //               child: BetterPlayer(controller: _controller),
//     //             ),
//     //             Card(
//     //               child: ListTile(
//     //                 title: CText('${widget.videoInfo.name}'),
//     //                 subtitle: CText(
//     //                   '${widget.videoInfo!.categoryId.toString()}',
//     //                   fontSize: 12,
//     //                   color: const Color.fromARGB(255, 202, 201, 201),
//     //                 ),
//     //               ),
//     //             ),
//     //           ],
//     //         ),
//     //         Expanded(
//     //           child: ListView.builder(
//     //             itemCount: 25,
//     //             itemBuilder: (context, index) {
//     //               VideosOnPerticulerChannelModel data =
//     //                   state.videoOnParticulerChannelList[index];
//     //               return Card(child: Text(index.toString()));
//     //             },
//     //           ),
//     //         ),
//     //       ],
//     //     );
//     //   },
//     // ),
//   }
// }
