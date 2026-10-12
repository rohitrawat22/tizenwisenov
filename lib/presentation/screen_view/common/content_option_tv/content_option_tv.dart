import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/localization/change_language_alert.dart';
import 'package:wiseplayertizen/core/localization/generated/l10n.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/core/utils/exit_dialog.dart';
import 'package:wiseplayertizen/core/utils/get_dymention.dart';
import 'package:wiseplayertizen/core/utils/snackbar.dart';
import 'package:wiseplayertizen/core/utils/toast_service.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/repo/api_repo.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/tabs/mylist/screens/favourite_list.dart';

import 'package:wiseplayertizen/presentation/screen_view/common/upload_playlist/upload_playlist.dart';
import 'package:wiseplayertizen/core/utils/breakpoints.dart';
import 'package:wiseplayertizen/core/widgets/geo_location_banner.dart';

import '../../../../core/widgets/laderScreen.dart';
import '../../../../data/local_storage/pin_security_service.dart';
import '../../../widgets/pin_input_dialog.dart';
import '../../bloc/model/get_playList_model.dart';

class CategoryPage extends StatefulWidget {
  static const String routeName = AppRoutes.categoryPage;
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with SingleTickerProviderStateMixin {
  ApiService apiService = ApiService();
  final FocusNode _refreshFocusNode = FocusNode();
  final FocusNode _dropdownFocusNode = FocusNode();
  final FocusNode _verifyButtonFocusNode = FocusNode();
  final FocusNode _backButtonFocusNode = FocusNode();
  final FocusNode _liveTvFocusNode = FocusNode();
  final FocusNode _moviesFocusNode = FocusNode();
  final FocusNode _seriesFocusNode = FocusNode();
  final FocusNode _favoritesFocusNode = FocusNode();
  final FocusNode _addNewPlaylistFocusNode = FocusNode();
  final FocusNode _languageFocusNode = FocusNode();
  final FocusNode _exitFocusNode = FocusNode();
  final FocusNode _pinSettingsFocusNode = FocusNode();

  final ValueNotifier<bool> _dropdownFocused = ValueNotifier(false);
  bool _isDropdownFocused = false;

  // No longer `late final` — it's now set in didChangeDependencies(),
  // not initState(), so it can't be final-assigned at declaration time.
  bool _isPhone = false;
  bool _isPhoneInitialized = false;

  GetplayListModel? selectedPlayList;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();

    // ── REMOVED from here: _isPhone = isPhoneWidth(context); ──
    // MediaQuery.of(context) (and any InheritedWidget lookup) is NOT safe
    // inside initState() — the element isn't fully attached to the tree yet.
    // It's now read in didChangeDependencies() below instead.

    _dropdownFocusNode.addListener(_onDropdownFocusChange);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    getPlaylist();

    // ── D-pad + Enter navigation setup — uses shared wireDpadNode helper ──
    //
    // Action button layout:
    //   Row 0 (playlist row):  [Select Playlist ▼]  [Verify]
    //   Row 1 (action row 1):  [Add New Playlist]   [Refresh]
    //   Row 2 (action row 2):  [Device PIN]         [Language]
    //   Row 3 (exit row):      [Exit (full width)]
    //   Right column:          [Live TV] [Movies]
    //                          [Series ] [Fav   ]
    wireDpadNode(
      _backButtonFocusNode,
      down: _dropdownFocusNode,
      right: _dropdownFocusNode,
      onSelect: () {
        if (Navigator.of(context).canPop())
          Navigator.of(context).pop();
        else
          GoRouter.of(context).pop();
      },
    );
    wireDpadNode(
      _dropdownFocusNode,
      up: _backButtonFocusNode,
      down: _addNewPlaylistFocusNode,
      right: _liveTvFocusNode,
      lockLeft: true,
      onSelect: () {
        if (!mounted) return;
        final playLists = BlocProvider.of<WiseBloc>(context).state.playLists;
        _openPlaylistManagementDialog(playLists);
      },
    );

    // Right-column category cards
    wireDpadNode(
      _liveTvFocusNode,
      up: _dropdownFocusNode,
      right: _moviesFocusNode,
      down: _seriesFocusNode,
      left: _refreshFocusNode,
      onSelect: () => _onMenuItemSelected(0),
    );
    wireDpadNode(
      _moviesFocusNode,
      up: _dropdownFocusNode,
      left: _liveTvFocusNode,
      down: _favoritesFocusNode,
      lockRight: true,
      onSelect: () => _onMenuItemSelected(1),
    );
    wireDpadNode(
      _seriesFocusNode,
      up: _liveTvFocusNode,
      left: _languageFocusNode,
      right: _favoritesFocusNode,
      lockDown: true,
      onSelect: () => _onMenuItemSelected(2),
    );
    wireDpadNode(
      _favoritesFocusNode,
      up: _moviesFocusNode,
      left: _seriesFocusNode,
      lockDown: true,
      lockRight: true,
      onSelect: () => _onMenuItemSelected(3),
    );

    // Left-column action buttons
    wireDpadNode(
      _addNewPlaylistFocusNode,
      up: _dropdownFocusNode,
      right: _refreshFocusNode,
      down: _pinSettingsFocusNode,
      lockLeft: true,
      onSelect: () => GoRouter.of(context).push(UploadPlaylist.routeName),
    );
    wireDpadNode(
      _refreshFocusNode,
      up: _dropdownFocusNode,
      left: _addNewPlaylistFocusNode,
      right: _liveTvFocusNode,
      down: _languageFocusNode,
      onSelect: () async {
        setState(() => selectedPlayList = null);
        await getPlaylist();
      },
    );
    wireDpadNode(
      _pinSettingsFocusNode,
      up: _addNewPlaylistFocusNode,
      right: _languageFocusNode,
      down: _exitFocusNode,
      lockLeft: true,
      onSelect: () => _showDevicePinSettings(),
    );
    wireDpadNode(
      _languageFocusNode,
      up: _refreshFocusNode,
      left: _pinSettingsFocusNode,
      down: _exitFocusNode,
      right: _seriesFocusNode,
      onSelect: () => showLanguageDialog(context),
    );
    wireDpadNode(
      _exitFocusNode,
      up: _pinSettingsFocusNode,
      lockDown: true,
      lockLeft: true,
      right: _seriesFocusNode,
      onSelect: () {
        S s = S.of(context);
        showExitDialog(context, s);
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dropdownFocusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe place to read MediaQuery / any InheritedWidget for the first time.
    // Runs once right after initState(), and again if an inherited
    // dependency changes later — the flag keeps the "capture once" behavior
    // your dispose() logic relies on.
    if (!_isPhoneInitialized) {
      _isPhone = isPhoneWidth(context);
      _isPhoneInitialized = true;
    }
  }

  void _onDropdownFocusChange() {
    _dropdownFocused.value = _dropdownFocusNode.hasFocus;
    _isDropdownFocused = _dropdownFocusNode.hasFocus;
  }

  rotateMode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isPhone) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });
  }

  bool _isFetchingPlaylist = false;

  Future<void> getPlaylist() async {
    if (_isFetchingPlaylist) return;
    _isFetchingPlaylist = true;
    try {
      final bloc = BlocProvider.of<WiseBloc>(context);
      bloc.add(GetPlayListEvent());
      bloc.add(ValidPlayListResetFlagEvent());
      // Wait a moment for the loading state to register, then await completion
      await Future.delayed(const Duration(milliseconds: 100));
      await bloc.stream.firstWhere((state) => state.status != Status.loading);
    } catch (_) {
    } finally {
      if (mounted) _isFetchingPlaylist = false;
    }
  }

  FocusNode get dropdownFocusNode => _dropdownFocusNode;
  FocusNode get verifyButtonFocusNode => _verifyButtonFocusNode;

  FocusNode getFocusNodeForIndex(int index) {
    switch (index) {
      case 0:
        return _liveTvFocusNode;
      case 1:
        return _moviesFocusNode;
      case 2:
        return _seriesFocusNode;
      case 3:
        return _favoritesFocusNode;
      default:
        // Never return a new FocusNode() here — it leaks and creates
        // phantom nodes in the focus tree. Fallback to liveTv safely.
        return _liveTvFocusNode;
    }
  }

  @override
  void dispose() {
    _dropdownFocusNode.removeListener(_onDropdownFocusChange);
    _dropdownFocusNode.dispose();
    _refreshFocusNode.dispose();
    _verifyButtonFocusNode.dispose();
    _backButtonFocusNode.dispose();
    _liveTvFocusNode.dispose();
    _moviesFocusNode.dispose();
    _seriesFocusNode.dispose();
    _favoritesFocusNode.dispose();
    _addNewPlaylistFocusNode.dispose();
    _languageFocusNode.dispose();
    _exitFocusNode.dispose();
    _pinSettingsFocusNode.dispose();
    _shimmerController.dispose();
    _dropdownFocused.dispose();
    if (_isPhone) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    S s = S.of(context);
    final size = MediaQuery.of(context).size;
    final isTV = size.width > 800;
    final isMobile = size.width < 600;

    return Directionality(
      // Always LTR for this screen — prevents Arabic RTL from inverting layout.
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColor.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: null,
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
          centerTitle: true,
          leadingWidth: 70,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: FocusableAppBarAction(
              focusNode: _backButtonFocusNode,
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  GoRouter.of(context).pop();
                }
              },
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F111A), // deep metallic obsidian
                Color(0xFF07080C), // deep black-blue
                Color(0xFF020203), // black
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: BlocConsumer<WiseBloc, WiseState>(
              listenWhen: (previous, current) =>
                  previous.status != current.status &&
                  (current.status == Status.littleError ||
                      current.status == Status.error),
              listener: (context, state) {
                if (state.status == Status.littleError ||
                    state.status == Status.error) {
                  ToastService.showError(
                    state.errorMessage.isNotEmpty
                        ? state.errorMessage
                        : s.somethingWentWrong,
                  );
                }
              },
              buildWhen: (previous, current) =>
                  previous.playLists != current.playLists ||
                  previous.isValidPlayList != current.isValidPlayList ||
                  (previous.status != current.status &&
                      (current.status == Status.initial ||
                          current.status == Status.loading ||
                          current.status == Status.success ||
                          current.status == Status.littleError)),
              builder: (context, state) {
                final List<GetplayListModel> playList = state.playLists;

                Widget child;

                if (state.status == Status.initial ||
                    state.status == Status.loading) {
                  child = const LoaderScreen(key: ValueKey('loader'));
                } else if (isTV) {
                  // ── TV layout: use LayoutBuilder so Expanded gets a finite height ──
                  child = LayoutBuilder(
                    key: const ValueKey('tv_content'),
                    builder: (context, constraints) {
                      // Responsive TV padding — scales with screen size, never too big
                      final tvPad = (constraints.maxWidth * 0.035).clamp(
                        12.0,
                        32.0,
                      );
                      final tvVPad = (constraints.maxHeight * 0.04).clamp(
                        10.0,
                        28.0,
                      );

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tvPad,
                          vertical: tvVPad,
                        ),
                        child: Column(
                          children: [
                            // ── Top: Geolocation & Time Banner ──
                            const GeoLocationBanner(),
                            const SizedBox(height: 12),
                            // ── Main Content Split ──
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Left Column: System controls & metadata ──
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        // --- Premium Playlist Selector ---
                                        _buildPlaylistSelector(
                                          playList,
                                          state,
                                          s,
                                          isTV,
                                          isMobile,
                                        ),
                                        const SizedBox(height: 14),
                                        // Action Buttons (Add, Refresh, Lang, Exit)
                                        _buildActionButtonsRow(
                                          isTV,
                                          isMobile,
                                          s,
                                        ),
                                        const SizedBox(height: 16),
                                        // MAC Address
                                        _buildMACAddress(
                                          isTV,
                                          isMobile,
                                          macAddress,
                                        ),
                                        const SizedBox(height: 10),
                                        // Footer Message
                                        _buildFooter(isTV, isMobile),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // ── Right Column: Categories (same width as left) ──
                                  Expanded(
                                    child: _buildMainMenuGridTV(
                                      isTV,
                                      isMobile,
                                      state,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                } else {
                  // ── Mobile / Tablet layout ──
                  child = RefreshIndicator(
                    key: const ValueKey('mobile_content'),
                    color: AppColor.accentCyan,
                    backgroundColor: AppColor.surfaceDark,
                    onRefresh: () async {
                      selectedPlayList = null;
                      await getPlaylist();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          // Responsive padding: 4% of width, clamped 10–20px
                          horizontal: (size.width * 0.04).clamp(10.0, 20.0),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 8),

                            // Geolocation and Time Banner
                            const GeoLocationBanner(),
                            const SizedBox(height: 8),

                            // --- Premium Playlist Selector ---
                            _buildPlaylistSelector(
                              playList,
                              state,
                              s,
                              isTV,
                              isMobile,
                            ),

                            const SizedBox(height: 12),

                            // Main Menu Grid
                            _buildMainMenuGrid(isTV, isMobile, state),

                            const SizedBox(height: 12),

                            // Action Buttons
                            _buildActionButtonsRow(isTV, isMobile, s),

                            const SizedBox(height: 10),

                            // MAC Address
                            _buildMACAddress(isTV, isMobile, macAddress),

                            const SizedBox(height: 8),

                            // Footer Message
                            _buildFooter(isTV, isMobile),

                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: child,
                );
              },
            ),
          ),
        ),
      ), // end Scaffold
    ); // end Directionality
  }

  // --- Premium Playlist Selector with Glassmorphic Design ---
  void _openPlaylistManagementDialog(List<GetplayListModel> playList) async {
    final result = await showDialog<GetplayListModel>(
      context: context,
      builder: (context) {
        return _PlaylistManagementDialog(
          playList: playList,
          selectedPlayList: selectedPlayList,
          onOpenPinSettings: () {
            Navigator.pop(context);
            _showDevicePinSettings();
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        selectedPlayList = result;
      });
      if (result.id != null && result.id!.isNotEmpty) {
        BlocProvider.of<WiseBloc>(context)
            .add(ValidPlayListCheckEvent(playListId: result.id!));
      }
    }
  }

  // --- Premium Playlist Selector Button opening the Playlist & Security Modal ---
  Widget _buildPlaylistSelector(
    List<GetplayListModel> playList,
    WiseState state,
    S s,
    bool isTV,
    bool isMobile,
  ) {
    final double selectorHeight = isTV ? 56 : (isMobile ? 44 : 48);
    final String currentTitle =
        selectedPlayList?.name ??
        (playList.isNotEmpty
            ? playList.first.name ?? s.selectPlaylist
            : s.selectPlaylist);

    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: _dropdownFocused,
            builder: (context, isFocused, _) {
              return AnimatedScale(
                scale: isFocused ? 1.03 : 1.0,
                duration: const Duration(milliseconds: 80),
                child: InkWell(
                  focusNode: _dropdownFocusNode,
                  autofocus: false,
                  onTap: () => _openPlaylistManagementDialog(playList),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    height: selectorHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: isFocused
                          ? LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.12),
                                AppColor.accentRed.withOpacity(0.2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.07),
                                Colors.white.withOpacity(0.02),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFocused
                            ? AppColor.accentRed.withOpacity(0.8)
                            : Colors.white.withOpacity(0.06),
                        width: isFocused ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColor.accentRed.withOpacity(0.25),
                          blurRadius: 20,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFocused
                                ? AppColor.accentRed
                                : AppColor.accentRed.withOpacity(0.15),
                          ),
                          child: Icon(
                            Icons.playlist_play_rounded,
                            color: Colors.white,
                            size: isTV ? 26 : 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTV ? 15 : 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                "Manage Playlists & Security PIN",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.swap_vert_rounded,
                          color: isFocused
                              ? AppColor.accentRed
                              : Colors.white.withOpacity(0.6),
                          size: isTV ? 24 : 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyButton(WiseState state, S s, bool isTV, bool isMobile) {
    final isVerified = state.isValidPlayList;
    final double selectorHeight = isTV ? 56 : (isMobile ? 44 : 48);
    return AnimatedBuilder(
      animation: _verifyButtonFocusNode,
      builder: (context, _) {
        final isFocused = _verifyButtonFocusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: InkWell(
            focusNode: _verifyButtonFocusNode,
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (selectedPlayList == null) {
                snackBar(context, s.choosePlaylistWarning, Colors.red);
                return;
              }
              if (selectedPlayList!.id!.isNotEmpty) {
                BlocProvider.of<WiseBloc>(context).add(
                  ValidPlayListCheckEvent(playListId: selectedPlayList!.id!),
                );
              } else {
                ToastService.showWarning(s.selectValidPlaylistToVerify);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              height: selectorHeight,
              padding: EdgeInsets.symmetric(horizontal: isTV ? 24 : 16),
              decoration: BoxDecoration(
                gradient: isFocused
                    ? (isVerified
                          ? const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFFB9090B)],
                            ))
                    : (isVerified
                          ? const LinearGradient(
                              colors: [Color(0xFF142B1B), Color(0xFF0F1E13)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF1E1E1E), Color(0xFF141414)],
                            )),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isFocused
                      ? Colors.white
                      : (isVerified
                            ? const Color(0xFF22C55E).withOpacity(0.3)
                            : Colors.white.withOpacity(0.08)),
                  width: isFocused ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isFocused
                        ? (isVerified
                              ? const Color(0xFF22C55E).withOpacity(0.4)
                              : const Color(0xFFE50914).withOpacity(0.4))
                        : Colors.black.withOpacity(0.3),
                    blurRadius: isFocused ? 20 : 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isVerified)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  Text(
                    isVerified ? s.verified : s.verify,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: isTV ? 15 : 13,
                      letterSpacing: 0.5,
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

  //--------------------------------------------------------------------------------------------------------------------

  goDashboard({
    required String playListId,
    bool isLiveTv = false,
    bool isMovies = false,
    bool isSeries = false,
    bool isRadio = false,
  }) {
    // Unify dashboard: Always use the landscape split-pane dashboard
    GoRouter.of(context)
        .push(
          AppRoutes.webDashboard,
          extra: {
            'playListId': playListId,
            'isLiveTv': isLiveTv,
            'isMovies': isMovies,
            'isSeries': isSeries,
            'isRadio': isRadio,
          },
        )
        .then((v) async {
          if (isPhone) {
            await SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ]);
          }
        });
  }

  List<_MenuItemModel> _getMenuItems(WiseState state, S s) {
    return [
      _MenuItemModel(
        image: 'assets/icons/live-tv.png',
        label: s.liveTv,
        gradient: const LinearGradient(
          colors: [Color(0xFFE50914), Color(0xFF7F0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () async {
          Map<String, dynamic> data = await SharedPref.getUserDeviceInfo();
          debugPrint(data['deviceSecret']);
          debugPrint(data['token']);
          if (selectedPlayList == null || selectedPlayList!.id!.isEmpty) {
            snackBar(context, s.choosePlaylistWarning, Colors.red);
            return;
          } else if (state.isValidPlayList) {
            if (state.status != Status.loading) {
              log("Live TV playlist id: ${selectedPlayList!.id!}");
              goDashboard(isLiveTv: true, playListId: selectedPlayList!.id!);
            }
          } else {
            snackBar(context, s.verifyPlaylistFirst, Colors.red);
          }
        },
      ),
      _MenuItemModel(
        image: "assets/icons/movies.png",
        label: s.movies,
        gradient: const LinearGradient(
          colors: [Color(0xFFE50914), Color(0xFF7F0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          if (selectedPlayList == null || selectedPlayList!.id!.isEmpty) {
            snackBar(context, s.choosePlaylistWarning, Colors.red);
            return;
          } else if (state.isValidPlayList) {
            goDashboard(isMovies: true, playListId: selectedPlayList!.id!);
          } else {
            snackBar(context, s.verifyPlaylistFirst, Colors.red);
          }
        },
      ),
      _MenuItemModel(
        image: 'assets/icons/series.png',
        label: s.series,
        gradient: const LinearGradient(
          colors: [Color(0xFFE50914), Color(0xFF7F0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          if (selectedPlayList == null || selectedPlayList!.id!.isEmpty) {
            snackBar(context, s.choosePlaylistWarning, Colors.red);
            return;
          } else if (state.isValidPlayList) {
            goDashboard(isSeries: true, playListId: selectedPlayList!.id!);
          } else {
            snackBar(context, s.verifyPlaylistFirst, Colors.red);
          }
        },
      ),
      _MenuItemModel(
        image: 'assets/icons/radio.png',
        label: s.favourite,
        gradient: const LinearGradient(
          colors: [Color(0xFFE50914), Color(0xFF7F0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => FavouriteScreen()));
        },
      ),
    ];
  }

  void _onMenuItemSelected(int index) {
    final state = BlocProvider.of<WiseBloc>(context).state;
    final s = S.of(context);
    final menuItems = _getMenuItems(state, s);
    if (index >= 0 && index < menuItems.length) {
      menuItems[index].onTap();
    }
  }

  Widget _buildMainMenuGridTV(bool isTV, bool isMobile, WiseState state) {
    S s = S.of(context);
    final menuItems = _getMenuItems(state, s);

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        final cardHeight = isTV ? 160.0 : 130.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMainMenuCard(
                  item: menuItems[0],
                  index: 0,
                  isTV: isTV,
                  isMobile: isMobile,
                  width: cardWidth,
                  height: cardHeight,
                ),
                const SizedBox(width: spacing),
                _buildMainMenuCard(
                  item: menuItems[1],
                  index: 1,
                  isTV: isTV,
                  isMobile: isMobile,
                  width: cardWidth,
                  height: cardHeight,
                ),
              ],
            ),
            const SizedBox(height: spacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMainMenuCard(
                  item: menuItems[2],
                  index: 2,
                  isTV: isTV,
                  isMobile: isMobile,
                  width: cardWidth,
                  height: cardHeight,
                ),
                const SizedBox(width: spacing),
                _buildMainMenuCard(
                  item: menuItems[3],
                  index: 3,
                  isTV: isTV,
                  isMobile: isMobile,
                  width: cardWidth,
                  height: cardHeight,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainMenuGrid(bool isTV, bool isMobile, WiseState state) {
    S s = S.of(context);
    final menuItems = _getMenuItems(state, s);

    // On Mobile: 2x2 grid layout (2 per row)
    if (isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const mobileSpacing = 10.0;
          final mobileCardWidth = (constraints.maxWidth - mobileSpacing) / 2;
          const mobileCardHeight = 100.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMainMenuCard(
                    item: menuItems[0],
                    index: 0,
                    isTV: isTV,
                    isMobile: isMobile,
                    width: mobileCardWidth,
                    height: mobileCardHeight,
                  ),
                  const SizedBox(width: mobileSpacing),
                  _buildMainMenuCard(
                    item: menuItems[1],
                    index: 1,
                    isTV: isTV,
                    isMobile: isMobile,
                    width: mobileCardWidth,
                    height: mobileCardHeight,
                  ),
                ],
              ),
              const SizedBox(height: mobileSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMainMenuCard(
                    item: menuItems[2],
                    index: 2,
                    isTV: isTV,
                    isMobile: isMobile,
                    width: mobileCardWidth,
                    height: mobileCardHeight,
                  ),
                  const SizedBox(width: mobileSpacing),
                  _buildMainMenuCard(
                    item: menuItems[3],
                    index: 3,
                    isTV: isTV,
                    isMobile: isMobile,
                    width: mobileCardWidth,
                    height: mobileCardHeight,
                  ),
                ],
              ),
            ],
          );
        },
      );
    }

    // On TV / Desktop: Single horizontal row layout
    double cardWidth = isTV ? 220 : 160;
    double cardHeight = isTV ? 128 : 115;
    final spacing = isTV ? 16.0 : 12.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMainMenuCard(
            item: menuItems[0],
            index: 0,
            isTV: isTV,
            isMobile: isMobile,
            width: cardWidth,
            height: cardHeight,
          ),
          SizedBox(width: spacing),
          _buildMainMenuCard(
            item: menuItems[1],
            index: 1,
            isTV: isTV,
            isMobile: isMobile,
            width: cardWidth,
            height: cardHeight,
          ),
          SizedBox(width: spacing),
          _buildMainMenuCard(
            item: menuItems[2],
            index: 2,
            isTV: isTV,
            isMobile: isMobile,
            width: cardWidth,
            height: cardHeight,
          ),
          SizedBox(width: spacing),
          _buildMainMenuCard(
            item: menuItems[3],
            index: 3,
            isTV: isTV,
            isMobile: isMobile,
            width: cardWidth,
            height: cardHeight,
          ),
        ],
      ),
    );
  }

  Widget _buildMainMenuCard({
    required _MenuItemModel item,
    required int index,
    required bool isTV,
    required bool isMobile,
    required double width,
    required double height,
  }) {
    // Use the existing named FocusNode — one node only, no double-focus.
    final cardFocusNode = getFocusNodeForIndex(index);
    return AnimatedBuilder(
      animation: cardFocusNode,
      builder: (context, _) {
        final isFocused = cardFocusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: InkWell(
            focusNode: cardFocusNode,
            borderRadius: BorderRadius.circular(24),
            onTap: item.onTap,
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 80),
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: isFocused
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF2E2E38),
                              Color(0xFF14141A),
                              Color(0xFF0A0A0F),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0x1BFFFFFF), Color(0x05FFFFFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isFocused
                          ? AppColor.accentRed
                          : Colors.white.withOpacity(0.06),
                      width: isFocused ? 2.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(isTV ? 8 : 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFocused
                              ? AppColor.accentRed
                              : Colors.white.withOpacity(0.04),
                        ),
                        child: Image.asset(
                          item.image,
                          color: isFocused
                              ? Colors.white
                              : Colors.white.withOpacity(0.55),
                          height: isTV ? 32 : (isMobile ? 24 : 28),
                          width: isTV ? 32 : (isMobile ? 24 : 28),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 8,
                          left: 4,
                          right: 4,
                        ),
                        child: Text(
                          item.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isTV ? 14 : (isMobile ? 11 : 12),
                            fontWeight: FontWeight.w700,
                            color: isFocused
                                ? Colors.white
                                : Colors.white.withOpacity(0.8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Glow rendered in separate GPU-composited layer — zero layout cost.
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: isFocused ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 80),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColor.accentRed.withOpacity(0.3),
                            blurRadius: 24,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtonsRow(bool isTV, bool isMobile, S s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = isTV ? 16.0 : (isMobile ? 12.0 : 14.0);
        final btnWidth = (constraints.maxWidth - spacing) / 2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: btnWidth,
                  child: _buildPremiumActionButton(
                    label: s.addNewPlaylist,
                    icon: Icons.add_circle_outline_rounded,
                    isTV: isTV,
                    isMobile: isMobile,
                    focusNode: _addNewPlaylistFocusNode,
                    onTap: () {
                      GoRouter.of(context).push(UploadPlaylist.routeName);
                    },
                  ),
                ),
                SizedBox(width: spacing),
                SizedBox(
                  width: btnWidth,
                  child: _buildPremiumActionButton(
                    label: s.refresh,
                    icon: Icons.refresh_rounded,
                    isTV: isTV,
                    isMobile: isMobile,
                    focusNode: _refreshFocusNode,
                    onTap: () async {
                      selectedPlayList = null;
                      await getPlaylist();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: btnWidth,
                  child: _buildPremiumActionButton(
                    label: "Device PIN",
                    icon: Icons.lock_outline_rounded,
                    isTV: isTV,
                    isMobile: isMobile,
                    focusNode: _pinSettingsFocusNode,
                    onTap: () => _showDevicePinSettings(),
                  ),
                ),
                SizedBox(width: spacing),
                SizedBox(
                  width: btnWidth,
                  child: _buildPremiumActionButton(
                    label: s.language,
                    icon: Icons.language_rounded,
                    isTV: isTV,
                    isMobile: isMobile,
                    focusNode: _languageFocusNode,
                    onTap: () async {
                      showLanguageDialog(context);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            SizedBox(
              width: constraints.maxWidth,
              child: _buildPremiumActionButton(
                label: s.exit,
                icon: Icons.power_settings_new_rounded,
                isTV: isTV,
                isMobile: isMobile,
                isDestructive: true,
                focusNode: _exitFocusNode,
                onTap: () {
                  showExitDialog(context, s);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Shows a center-screen Dialog with options to Set, Change, or Remove the device PIN.
  void _showDevicePinSettings() async {
    final pinService = PinSecurityService();
    final hasPin = await pinService.isPinCreated();

    if (!mounted) return;

    final action = await showDialog<String>(
      context: context,
      builder: (context) {
        return _DevicePinSettingsDialog(hasPin: hasPin);
      },
    );

    if (action == null || !mounted) return;

    switch (action) {
      case 'set':
        final newPin = await showDialog<String>(
          context: context,
          builder: (context) => const PinInputDialog(
            mode: PinDialogMode.setup,
            titleOverride: "Set Device PIN",
          ),
        );
        if (newPin != null && newPin.length == 4 && mounted) {
          BlocProvider.of<WiseBloc>(context)
              .add(SetDevicePinEvent(pin: newPin));
          ToastService.showSuccess("Device PIN setting requested");
        }
        break;

      case 'change':
        final result = await showDialog<Map<String, String>>(
          context: context,
          builder: (context) => const PinInputDialog(
            mode: PinDialogMode.change,
            titleOverride: "Change Device PIN",
          ),
        );
        if (result != null && mounted) {
          try {
            _showLoader(context);
            final apiRepo = ApiRepo(apiService: ApiService());
            await apiRepo.verifyDevicePin(result['oldPin']!);
            if (mounted) _stopLoader(context);
            BlocProvider.of<WiseBloc>(context).add(
              ChangePinEvent(
                oldPin: result['oldPin']!,
                newPin: result['newPin']!,
              ),
            );
            ToastService.showSuccess("Device PIN change requested");
          } catch (e) {
            if (mounted) _stopLoader(context);
            ToastService.showError(
              e.toString().replaceAll("ServerException: ", ""),
            );
          }
        }
        break;

      case 'remove':
        final currentPin = await showDialog<String>(
          context: context,
          builder: (context) => const PinInputDialog(
            mode: PinDialogMode.remove,
            titleOverride: "Remove Device PIN",
          ),
        );
        if (currentPin != null && mounted) {
          try {
            _showLoader(context);
            final apiRepo = ApiRepo(apiService: ApiService());
            await apiRepo.verifyDevicePin(currentPin);
            if (mounted) _stopLoader(context);
            BlocProvider.of<WiseBloc>(context)
                .add(RemoveDevicePinEvent(currentPin: currentPin));
            ToastService.showSuccess("Device PIN removal requested");
          } catch (e) {
            if (mounted) _stopLoader(context);
            ToastService.showError(
              e.toString().replaceAll("ServerException: ", ""),
            );
          }
        }
        break;
    }
  }

  void _showLoader(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoaderScreen(key: ValueKey('pin_loader')),
    );
  }

  void _stopLoader(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Widget _buildPremiumActionButton({
    required String label,
    required IconData icon,
    required bool isTV,
    required bool isMobile,
    required VoidCallback onTap,
    required FocusNode focusNode,
    bool isDestructive = false,
  }) {
    // AnimatedBuilder on the actual FocusNode — no double node.
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: InkWell(
            focusNode: focusNode,
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              height: isTV ? 48 : (isMobile ? 38 : 42),
              decoration: BoxDecoration(
                gradient: isFocused
                    ? (isDestructive
                          ? const LinearGradient(
                              colors: [Color(0xFFB9090B), Color(0xFF7F0000)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFF7F0000)],
                            ))
                    : const LinearGradient(
                        colors: [Color(0x1BFFFFFF), Color(0x05FFFFFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused
                      ? Colors.white
                      : Colors.white.withOpacity(0.06),
                  width: isFocused ? 2.0 : 1.0,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color:
                              (isDestructive
                                      ? const Color(0xFFB9090B)
                                      : const Color(0xFFE50914))
                                  .withOpacity(0.35),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: isFocused
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                          size: isTV ? 18 : (isMobile ? 14 : 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: isTV ? 14 : (isMobile ? 11 : 13),
                            fontWeight: FontWeight.w600,
                            color: isFocused
                                ? Colors.white
                                : Colors.white.withOpacity(0.8),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMACAddress(bool isTV, bool isMobile, macNumber) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColor.surfaceDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColor.accentCyan.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.router_outlined,
            color: AppColor.accentCyan.withOpacity(0.5),
            size: isTV ? 16 : 14,
          ),
          const SizedBox(width: 8),
          Text(
            '${s.macLabel}: $macNumber',
            style: TextStyle(
              fontSize: isTV ? 14 : (isMobile ? 11 : 13),
              color: AppColor.moreLightGrey.withOpacity(0.7),
              letterSpacing: 1.2,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isTV, bool isMobile) {
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTV ? 40 : 20),
      child: Text(
        s.tvOnlyWarning,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isTV ? 12 : (isMobile ? 10 : 11),
          color: AppColor.moreLightGrey.withOpacity(0.4),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MenuItemModel {
  final String image;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  _MenuItemModel({
    required this.image,
    required this.label,
    required this.gradient,
    required this.onTap,
  });
}

class FocusAutoScroll extends StatefulWidget {
  final Widget child;
  const FocusAutoScroll({super.key, required this.child});

  @override
  State<FocusAutoScroll> createState() => _FocusAutoScrollState();
}

class _FocusAutoScrollState extends State<FocusAutoScroll> {
  void _onFocusChange(bool hasFocus) {
    if (!hasFocus) return;
    // Defer to next frame so the widget is guaranteed to be laid out before
    // Scrollable.ensureVisible tries to access its render box size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = context;
      // Only scroll if this widget is actually inside a Scrollable ancestor.
      if (Scrollable.maybeOf(ctx) == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onFocusChange: _onFocusChange,
      child: widget.child,
    );
  }
}

class FocusableAppBarAction extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final FocusNode focusNode;

  const FocusableAppBarAction({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    // Single FocusNode, AnimatedBuilder — no double-focus.
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: InkWell(
            focusNode: focusNode,
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isFocused
                    ? Colors.white.withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isFocused
                      ? Colors.white.withOpacity(0.3)
                      : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: icon,
            ),
          ),
        );
      },
    );
  }
}

class _DevicePinSettingsDialog extends StatefulWidget {
  final bool hasPin;
  const _DevicePinSettingsDialog({Key? key, required this.hasPin})
    : super(key: key);

  @override
  State<_DevicePinSettingsDialog> createState() =>
      _DevicePinSettingsDialogState();
}

class _DevicePinSettingsDialogState extends State<_DevicePinSettingsDialog> {
  final FocusNode _setNode = FocusNode(debugLabel: 'pin_set');
  final FocusNode _changeNode = FocusNode(debugLabel: 'pin_change');
  final FocusNode _removeNode = FocusNode(debugLabel: 'pin_remove');
  final FocusNode _closeFocusNode = FocusNode(
    debugLabel: 'settings_dialog_close',
  );

  @override
  void initState() {
    super.initState();

    // Wire D-pad navigation for the close and cancel buttons + settings options
    wireDpadNode(
      _closeFocusNode,
      lockUp: true,
      lockLeft: true,
      lockRight: true,
      down: !widget.hasPin ? _setNode : _changeNode,
      onSelect: () => Navigator.pop(context),
    );

    if (!widget.hasPin) {
      // Only 'Set PIN' option shown
      wireDpadNode(
        _setNode,
        up: _closeFocusNode,
        lockDown: true,
        lockLeft: true,
        lockRight: true,
        onSelect: () => Navigator.pop(context, 'set'),
      );
    } else {
      // 'Change PIN' (top) + 'Remove PIN' (bottom)
      wireDpadNode(
        _changeNode,
        up: _closeFocusNode,
        down: _removeNode,
        lockLeft: true,
        lockRight: true,
        onSelect: () => Navigator.pop(context, 'change'),
      );
      wireDpadNode(
        _removeNode,
        up: _changeNode,
        lockDown: true,
        lockLeft: true,
        lockRight: true,
        onSelect: () => Navigator.pop(context, 'remove'),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.hasPin) {
        _setNode.requestFocus();
      } else {
        _changeNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _setNode.dispose();
    _changeNode.dispose();
    _removeNode.dispose();
    _closeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Focus(
        autofocus: false,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final k = event.logicalKey;
          if (k == LogicalKeyboardKey.escape ||
              k == LogicalKeyboardKey.goBack ||
              k == LogicalKeyboardKey.browserBack) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          child: Container(
            width: 480,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF141820),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColor.accentRed.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColor.accentRed.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColor.accentRed.withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.security_rounded,
                          color: AppColor.accentRed,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Device PIN Settings",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Secure access to public playlists on this device.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          widget.hasPin
                              ? "Status: PIN is currently SET"
                              : "Status: Default PIN (0000) active",
                          style: TextStyle(
                            color: widget.hasPin
                                ? AppColor.accentGreen
                                : AppColor.accentRed,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!widget.hasPin)
                        _pinSettingsOption(
                          focusNode: _setNode,
                          icon: Icons.lock_outline,
                          label: "Set Device PIN",
                          subtitle: "Create a 4-digit PIN",
                          onTap: () => Navigator.pop(context, 'set'),
                        ),
                      if (widget.hasPin) ...[
                        _pinSettingsOption(
                          focusNode: _changeNode,
                          icon: Icons.edit_outlined,
                          label: "Change PIN",
                          subtitle: "Verify current PIN, then set a new one",
                          onTap: () => Navigator.pop(context, 'change'),
                        ),
                        const SizedBox(height: 10),
                        _pinSettingsOption(
                          focusNode: _removeNode,
                          icon: Icons.lock_open_outlined,
                          label: "Remove PIN",
                          subtitle: "Revert to default (0000)",
                          isDestructive: true,
                          onTap: () => Navigator.pop(context, 'remove'),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _DialogCloseButton(
                    focusNode: _closeFocusNode,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pinSettingsOption({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        final activeColor = isDestructive
            ? Colors.redAccent
            : AppColor.accentRed;
        return AnimatedScale(
          scale: isFocused ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: InkWell(
            focusNode: focusNode,
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isFocused
                    ? activeColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isFocused
                      ? activeColor
                      : Colors.white.withValues(alpha: 0.08),
                  width: isFocused ? 2 : 1,
                ),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor.withValues(alpha: 0.2),
                    ),
                    child: Icon(
                      icon,
                      color: isFocused
                          ? Colors.white
                          : (isDestructive ? Colors.redAccent : Colors.white70),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isFocused
                                ? Colors.white
                                : (isDestructive
                                      ? Colors.redAccent
                                      : Colors.white),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isFocused
                                ? Colors.white.withOpacity(0.7)
                                : Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isFocused
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated ✕ close button used inside dialog headers.
/// Fully focusable (TV D-pad) and tap-able (touch).
class _DialogCloseButton extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  const _DialogCloseButton({required this.focusNode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, _) {
        final isFocused = focusNode.hasFocus;
        return AnimatedScale(
          scale: isFocused ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: InkWell(
            focusNode: focusNode,
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFocused
                    ? AppColor.accentRed.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                border: Border.all(
                  color: isFocused
                      ? AppColor.accentRed
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: isFocused
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Professional TV-Optimized Modal Dialog for Managing Playlists & Security PINs.
class _PlaylistManagementDialog extends StatefulWidget {
  final List<GetplayListModel> playList;
  final GetplayListModel? selectedPlayList;
  final VoidCallback onOpenPinSettings;

  const _PlaylistManagementDialog({
    Key? key,
    required this.playList,
    required this.selectedPlayList,
    required this.onOpenPinSettings,
  }) : super(key: key);

  @override
  State<_PlaylistManagementDialog> createState() =>
      _PlaylistManagementDialogState();
}

class _PlaylistManagementDialogState extends State<_PlaylistManagementDialog> {
  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'popup_close');
  final FocusNode _pinSettingsFocusNode = FocusNode(
    debugLabel: 'popup_pin_settings',
  );
  final Map<int, FocusNode> _selectNodes = {};
  final Map<int, FocusNode> _pinNodes = {};
  final Map<int, FocusNode> _lockNodes = {};

  // Local sorted copy: selected first, then pinned, then rest
  late List<GetplayListModel> _sortedList;

  @override
  void initState() {
    super.initState();
    _sortedList = _buildSortedList();
    _wireNodes();
    // Request initial focus ONE TIME only — not inside _wireNodes so that
    // subsequent re-wiring (e.g. after a pin toggle) doesn't steal focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_sortedList.isNotEmpty) {
          _getSelectNode(0).requestFocus();
        } else {
          _closeFocusNode.requestFocus();
        }
      }
    });
  }

  List<GetplayListModel> _buildSortedList() {
    final selected = widget.selectedPlayList;
    final list = List<GetplayListModel>.from(widget.playList);
    list.sort((a, b) {
      final aIsSelected = selected != null && a.id == selected.id;
      final bIsSelected = selected != null && b.id == selected.id;
      if (aIsSelected && !bIsSelected) return -1;
      if (!aIsSelected && bIsSelected) return 1;
      final aPinned = a.isPinned == true;
      final bPinned = b.isPinned == true;
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });
    return list;
  }

  void _wireNodes() {
    wireDpadNode(
      _closeFocusNode,
      lockUp: true,
      lockLeft: true,
      right: _pinSettingsFocusNode,
      down: _sortedList.isNotEmpty ? _getSelectNode(0) : null,
      onSelect: () => Navigator.pop(context),
    );

    wireDpadNode(
      _pinSettingsFocusNode,
      lockUp: true,
      lockRight: true,
      left: _closeFocusNode,
      down: _sortedList.isNotEmpty ? _getSelectNode(0) : null,
      onSelect: () {
        widget.onOpenPinSettings();
      },
    );

    for (int i = 0; i < _sortedList.length; i++) {
      final selectNode = _getSelectNode(i);
      final pinNode = _getPinNode(i);
      final lockNode = _getLockNode(i);

      final prevSelect = i > 0 ? _getSelectNode(i - 1) : _closeFocusNode;
      final nextSelect = i < _sortedList.length - 1
          ? _getSelectNode(i + 1)
          : null;
      final item = _sortedList[i];

      wireDpadNode(
        selectNode,
        up: prevSelect,
        down: nextSelect,
        right: pinNode,
        lockLeft: true,
        onSelect: () => _selectPlaylist(item),
      );

      wireDpadNode(
        pinNode,
        up: i > 0 ? _getPinNode(i - 1) : _pinSettingsFocusNode,
        down: i < _sortedList.length - 1 ? _getPinNode(i + 1) : null,
        left: selectNode,
        right: lockNode,
        onSelect: () => _togglePin(item),
      );

      wireDpadNode(
        lockNode,
        up: i > 0 ? _getLockNode(i - 1) : _pinSettingsFocusNode,
        down: i < _sortedList.length - 1 ? _getLockNode(i + 1) : null,
        left: pinNode,
        lockRight: true,
        onSelect: () => _toggleLock(item),
      );
    }

    // NOTE: Initial focus is requested ONCE from initState, NOT here.
    // Re-calling _wireNodes (e.g. after a pin toggle) must NOT steal focus
    // away from wherever the user's cursor currently is.
  }

  /// Selects a playlist. If it is locked, prompts for PIN verification first.
  void _selectPlaylist(GetplayListModel item) async {
    if (item.isLocked == true) {
      final pinService = PinSecurityService();
      final enteredPin = await showDialog<String>(
        context: context,
        builder: (context) => const PinInputDialog(
          mode: PinDialogMode.verify,
          titleOverride: "Enter Playlist PIN",
        ),
      );
      if (enteredPin == null || !mounted) return;
      final isValid = await pinService.verifyPlaylistPin(
        playlistId: item.id!,
        pin: enteredPin,
      );
      if (!mounted) return;
      if (!isValid) {
        ToastService.showError("Incorrect PIN");
        return;
      }
    }
    if (mounted) Navigator.pop(context, item);
  }

  FocusNode _getSelectNode(int i) =>
      _selectNodes.putIfAbsent(i, () => FocusNode(debugLabel: 'select_$i'));
  FocusNode _getPinNode(int i) =>
      _pinNodes.putIfAbsent(i, () => FocusNode(debugLabel: 'pin_$i'));
  FocusNode _getLockNode(int i) =>
      _lockNodes.putIfAbsent(i, () => FocusNode(debugLabel: 'lock_$i'));

  @override
  void dispose() {
    _closeFocusNode.dispose();
    _pinSettingsFocusNode.dispose();
    for (final n in _selectNodes.values) {
      n.dispose();
    }
    for (final n in _pinNodes.values) {
      n.dispose();
    }
    for (final n in _lockNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _toggleLock(GetplayListModel e) async {
    final pinService = PinSecurityService();
    if (e.isLocked == true) {
      final enteredPin = await showDialog<String>(
        context: context,
        builder: (context) => const PinInputDialog(
          mode: PinDialogMode.verify,
          titleOverride: "Enter Playlist PIN",
        ),
      );
      if (enteredPin != null && mounted) {
        final isValid = await pinService.verifyPlaylistPin(
          playlistId: e.id!,
          pin: enteredPin,
        );
        if (isValid) {
          BlocProvider.of<WiseBloc>(context)
              .add(TogglePlaylistLockEvent(playlistId: e.id!, isLocked: false));
          await pinService.removePlaylistPin(e.id!);
          setState(() {});
        } else {
          ToastService.showError("Incorrect PIN");
        }
      }
    } else {
      final newPin = await showDialog<String>(
        context: context,
        builder: (context) => const PinInputDialog(
          mode: PinDialogMode.setup,
          titleOverride: "Create Playlist PIN",
        ),
      );
      if (newPin != null && newPin.length == 4 && mounted) {
        await pinService.setPlaylistPin(playlistId: e.id!, pin: newPin);
        BlocProvider.of<WiseBloc>(context)
            .add(TogglePlaylistLockEvent(playlistId: e.id!, isLocked: true));
        setState(() {});
      }
    }
  }

  void _togglePin(GetplayListModel item) {
    if (item.isPinned == true) {
      BlocProvider.of<WiseBloc>(context)
          .add(UnpinPlaylistEvent(playlistId: item.id!));
    } else {
      BlocProvider.of<WiseBloc>(context)
          .add(PinPlaylistEvent(playlistId: item.id!));
    }
    // Optimistic update of the local list for immediate UI transition
    setState(() {
      if (item.isPinned == true) {
        item.isPinned = false;
      } else {
        item.isPinned = true;
      }
      _sortedList = _buildSortedList();
      _wireNodes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenW = screenSize.width;
    final screenH = screenSize.height;
    // Responsive width: 90% of screen on small TVs, max 560 on large TVs
    final dialogWidth = (screenW * 0.88).clamp(320.0, 560.0);
    // Wrap in PopScope so TV Back key pops only this dialog, not the whole route
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop();
      },
      child: Focus(
        // Root focus: captures Enter/Back not already handled by child nodes
        autofocus: false,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final k = event.logicalKey;
          if (k == LogicalKeyboardKey.escape ||
              k == LogicalKeyboardKey.goBack ||
              k == LogicalKeyboardKey.browserBack) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: screenH * 0.85),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF10131B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColor.accentRed.withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColor.accentRed.withValues(alpha: 0.18),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColor.accentRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.featured_play_list_rounded,
                        color: AppColor.accentRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Manage Playlists & Security",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            "Select a playlist or toggle lock",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pinSettingsFocusNode,
                      builder: (context, _) {
                        final isFocused = _pinSettingsFocusNode.hasFocus;
                        return AnimatedScale(
                          scale: isFocused ? 1.05 : 1.0,
                          duration: const Duration(milliseconds: 80),
                          child: InkWell(
                            focusNode: _pinSettingsFocusNode,
                            onTap: widget.onOpenPinSettings,
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 80),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isFocused
                                    ? AppColor.accentRed.withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isFocused
                                      ? AppColor.accentRed
                                      : Colors.white10,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.shield_rounded,
                                    size: 14,
                                    color: isFocused
                                        ? AppColor.accentRed
                                        : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "PIN Security",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isFocused
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _DialogCloseButton(
                      focusNode: _closeFocusNode,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),
                Flexible(
                  child: widget.playList.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              "No Playlists Available",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _sortedList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _sortedList[index];
                            final isSelected =
                                widget.selectedPlayList?.id == item.id;
                            final selectNode = _getSelectNode(index);
                            final pinNode = _getPinNode(index);
                            final lockNode = _getLockNode(index);

                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColor.accentRed.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColor.accentRed.withValues(
                                          alpha: 0.5,
                                        )
                                      : Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: AnimatedBuilder(
                                      animation: selectNode,
                                      builder: (context, _) {
                                        final isFocused = selectNode.hasFocus;
                                        return AnimatedScale(
                                          scale: isFocused ? 1.02 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 80,
                                          ),
                                          child: InkWell(
                                            focusNode: selectNode,
                                            onTap: () => _selectPlaylist(item),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 80,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isFocused
                                                    ? AppColor.accentRed
                                                          .withValues(
                                                            alpha: 0.25,
                                                          )
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isFocused
                                                      ? AppColor.accentRed
                                                      : Colors.transparent,
                                                  width: isFocused ? 2.0 : 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isSelected
                                                        ? Icons
                                                              .check_circle_rounded
                                                        : Icons
                                                              .radio_button_unchecked_rounded,
                                                    color: isSelected
                                                        ? AppColor.accentRed
                                                        : Colors.white38,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Flexible(
                                                              child: Text(
                                                                item.name ??
                                                                    "Playlist #${index + 1}",
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      isSelected
                                                                      ? FontWeight
                                                                            .bold
                                                                      : FontWeight
                                                                            .w600,
                                                                ),
                                                              ),
                                                            ),
                                                            if (item.isLocked ==
                                                                true) ...[
                                                              const SizedBox(
                                                                width: 6,
                                                              ),
                                                              const Icon(
                                                                Icons
                                                                    .lock_rounded,
                                                                color: AppColor
                                                                    .accentRed,
                                                                size: 13,
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          "ID: ${item.id ?? 'N/A'}",
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white38,
                                                                fontSize: 10,
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
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Pin / Unpin Button
                                  AnimatedBuilder(
                                    animation: pinNode,
                                    builder: (context, _) {
                                      final isFocused = pinNode.hasFocus;
                                      final isPinned = item.isPinned == true;
                                      return AnimatedScale(
                                        scale: isFocused ? 1.1 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 80,
                                        ),
                                        child: InkWell(
                                          focusNode: pinNode,
                                          onTap: () => _togglePin(item),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 80,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isFocused
                                                  ? AppColor.accentRed
                                                        .withValues(alpha: 0.2)
                                                  : (isPinned
                                                        ? Colors.white
                                                              .withValues(
                                                                alpha: 0.1,
                                                              )
                                                        : Colors.white
                                                              .withValues(
                                                                alpha: 0.05,
                                                              )),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isFocused
                                                    ? AppColor.accentRed
                                                    : Colors.transparent,
                                              ),
                                            ),
                                            child: Icon(
                                              isPinned
                                                  ? Icons.push_pin_rounded
                                                  : Icons.push_pin_outlined,
                                              size: 18,
                                              color: isPinned
                                                  ? Colors.white
                                                  : Colors.white60,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  // Lock / Unlock Button
                                  AnimatedBuilder(
                                    animation: lockNode,
                                    builder: (context, _) {
                                      final isFocused = lockNode.hasFocus;
                                      return AnimatedScale(
                                        scale: isFocused ? 1.1 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 80,
                                        ),
                                        child: InkWell(
                                          focusNode: lockNode,
                                          onTap: () => _toggleLock(item),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 80,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isFocused
                                                  ? AppColor.accentRed
                                                        .withValues(alpha: 0.2)
                                                  : Colors.white.withValues(
                                                      alpha: 0.05,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isFocused
                                                    ? AppColor.accentRed
                                                    : Colors.transparent,
                                              ),
                                            ),
                                            child: Icon(
                                              item.isLocked == true
                                                  ? Icons.lock_rounded
                                                  : Icons.lock_open_rounded,
                                              size: 18,
                                              color: item.isLocked == true
                                                  ? AppColor.accentRed
                                                  : Colors.white60,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ), // end Dialog
      ), // end Focus
    ); // end PopScope
  }
}
