import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/main.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/auth/login_with_mac.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/auth/fetch_phone_info_mac.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/auth/wise_player_tv_home_screen.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/content_option_tv/content_option_tv.dart';
import 'package:wiseplayertizen/presentation/screen_view/mobile/moblie_dashboard_screen.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/pay_pal_chekout_screen.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/show_subsciption_plan.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/tv_show_subscription_plan.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/upload_playlist/upload_playlist.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/upload_playlist/tv_upload_playlist_screen.dart';
import 'package:wiseplayertizen/presentation/screen_view/responsive/responsive_layout.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/splash/splash_screen.dart';
import 'package:wiseplayertizen/presentation/screen_view/mobile/dashboard.dart';
import 'package:wiseplayertizen/presentation/screen_view/web/screens/stream_player.dart';
import 'package:wiseplayertizen/presentation/screen_view/web/screens/web_dashboard_screen.dart';
import 'package:wiseplayertizen/series/serie.details.dart';
import 'package:wiseplayertizen/tv.video.dart'
    show SimpleVideoScreen, TizenVideoScreen;

import '../../presentation/screen_view/bloc/model/videos_on_particuler_channel_model.dart';

/// Routes that don't require authentication
const _publicRoutes = {
  AppRoutes.splashScreen,
  AppRoutes.loginWithMac,
  AppRoutes.fetchPhoneInfoMac,
  AppRoutes.tvHomeScreen, // TV home handles its own auth checks internally
  AppRoutes.tvUploadPlaylist, // TV screens handle their own auth guard
  AppRoutes.tvSubscriptionPlan,
};

final GoRouter router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: AppRoutes.splashScreen,
  redirect: (BuildContext context, GoRouterState state) async {
    final location = state.uri.toString();

    // Allow public routes without auth check
    if (_publicRoutes.any((r) => location.startsWith(r))) {
      return null;
    }

    // Check if user is authenticated
    final bool isAuthenticated = await SharedPref.getUserDeviceStatus();
    if (!isAuthenticated) {
      // Redirect unauthenticated users to the device info / auth screen
      return AppRoutes.fetchPhoneInfoMac;
    }

    return null; // Authenticated — allow access
  },
  routes: [
    GoRoute(
      path: AppRoutes.splashScreen,
      builder: (context, state) => SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.screenLayout,
      builder: (context, state) => ScreenLayoutScreen(),
    ),

    GoRoute(
      path: AppRoutes.webDashboard,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        final String playListId = data['playListId'];
        final bool isLiveTv = data['isLiveTv'];
        final bool isMovies = data['isMovies'];
        final bool isSeries = data['isSeries'];
        final bool isRadio = data['isRadio'];
        return WebDashboardScreen(
          playListId: playListId,
          isLiveTv: isLiveTv,
          isMovies: isMovies,
          isSeries: isSeries,
          isRadio: isRadio,
        );
      },
    ),

    GoRoute(
      path: AppRoutes.mobileDashboard,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        final String playListId = data['playListId'];
        final bool isLiveTv = data['isLiveTv'];
        final bool isMovies = data['isMovies'];
        final bool isSeries = data['isSeries'];
        final bool isRadio = data['isRadio'];
        return MoblieDashboardScreen(
          playListId: playListId,
          isLiveTv: isLiveTv,
          isMovies: isMovies,
          isSeries: isSeries,
          isRadio: isRadio,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.loginWithMac,
      builder: (context, state) {
        String deviceKey = (state.extra as String?) ?? '';
        return LoginWithMac(deviceKey: deviceKey);
      },
    ),
    GoRoute(
      path: AppRoutes.fetchPhoneInfoMac,
      builder: (context, state) => const FetchPhoneInfoMac(),
    ),
    // TV-only home screen — routed to from FetchPhoneInfoMac on TV detection.
    GoRoute(
      path: AppRoutes.tvHomeScreen,
      builder: (context, state) => const WisePlayerTVHomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) {
        return DashboardScreen();
      },
    ),

    // ── Phone / original route — UNCHANGED ────────────────────────────────
    GoRoute(
      path: AppRoutes.uploadPlaylist,
      builder: (context, state) => const UploadPlaylist(),
    ),
    // ── TV-only route — only navigated to from WisePlayerTVHomeScreen ──────
    GoRoute(
      path: AppRoutes.tvUploadPlaylist,
      builder: (context, state) => const TVUploadPlaylistScreen(),
    ),
    GoRoute(
      path: AppRoutes.categoryPage,
      builder: (context, state) {
        return CategoryPage();
      },
    ),
    GoRoute(
      path: AppRoutes.videoPlayer,
      builder: (context, state) {
        Map<String, dynamic> data = state.extra as Map<String, dynamic>;
        final String url = data['videoUrl'];
        final VideosOnPerticulerChannelModel videoInfoData = data['videoInfo'];
        final bool isLiveTv = data['isLiveTv'] as bool? ?? true;
        final String streaID = data['streaID'] ?? "";
        final String playlistId = data['playlistId'] ?? "";
        final String streamType = data['streamType'] ?? "";
        final int resumeSecond = data['resumeSecond'] ?? "";
        final List<EpgProgramModel>? programList = data['programList'] ?? [];
        return VideoPlayerScreen(
          streaID: streaID,
          videoUrl: url,
          videoInfo: videoInfoData,
          resumeSecond: resumeSecond,
          playlistId: playlistId,
          streamType: streamType,
          programList: programList,
          isLiveTv: isLiveTv,
        );
      },
    ),
    // ── Phone / original route — UNCHANGED ────────────────────────────────
    GoRoute(
      path: AppRoutes.showSubsciptionPlan,
      builder: (context, state) => ShowSubsciptionPlan(),
    ),
    // ── TV-only route — only navigated to from WisePlayerTVHomeScreen ──────
    GoRoute(
      path: AppRoutes.tvSubscriptionPlan,
      builder: (context, state) => const TVSubscriptionPlanScreen(),
    ),

    GoRoute(
      path: AppRoutes.paypalCheckoutScreen,
      builder: (context, state) {
        return PayPalCheckoutScreen();
      },
    ),
  ],
);

customTransition({
  required Function(GoRouterState state) pageBuilder,
  startingDuration = 400,
  reverseDuration = 200,
}) {
  return (context, state) {
    return CustomTransitionPage(
      key: state.pageKey,
      transitionDuration: Duration(milliseconds: startingDuration),
      reverseTransitionDuration: Duration(milliseconds: reverseDuration),
      child: pageBuilder(state),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return CupertinoPageTransition(
          primaryRouteAnimation: animation,
          secondaryRouteAnimation: secondaryAnimation,
          linearTransition: true,
          child: child,
        );
      },
    );
  };
}
