import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/routes/routes_path.dart';
import 'package:wiseplayertizen/core/utils/breakpoints.dart';
import 'package:wiseplayertizen/core/utils/loader.dart';
import 'package:wiseplayertizen/core/utils/message_dialog.dart';
import 'package:wiseplayertizen/core/utils/snackbar.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/pay_pal_chekout_screen.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/qr_checkout_tv_screen.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/plan.model.dart';

import '../../../../core/widgets/custom_text.dart';

class ShowSubsciptionPlan extends StatefulWidget {
  static final String routeName = AppRoutes.showSubsciptionPlan;

  const ShowSubsciptionPlan({super.key});

  @override
  State<ShowSubsciptionPlan> createState() => _ShowSubsciptionPlanState();
}

class _ShowSubsciptionPlanState extends State<ShowSubsciptionPlan>
    with SingleTickerProviderStateMixin {
  // ── Focus nodes ────────────────────────────────────────────────────────────
  final FocusNode _backBtnNode = FocusNode(debugLabel: 'sub_back');
  final FocusNode _continueBtnNode = FocusNode(debugLabel: 'sub_continue');
  final List<FocusNode> _planNodes = [];

  late AnimationController _glowController;
  int selectedIndex = 0;
  List<AvailablePlanModel> allplanList = [];
  final ScrollController _scrollController = ScrollController();

  // Captured in initState() so it remains valid in dispose() and in
  // postFrameCallback handlers — MediaQuery is unsafe in deactivated elements.
  late final bool _isPhone;
  bool _didInitDependentState = false; // NEW: guard flag

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    getPlanData();

    // Force portrait on phones — this screen is a vertical scroll layout
    // and may be opened while the device is still in landscape (e.g. from
    // the dashboard). Without this, the layout looks broken on phones.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isPhone) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    });

    // Wire back button — down goes to first plan (once loaded)
    wireDpadNode(
      _backBtnNode,
      down: _planNodes.isNotEmpty ? _planNodes[0] : null,
      lockUp: true,
      lockLeft: true,
      lockRight: true,
      onSelect: () => GoRouter.of(context).pop(),
    );

    // Wire continue button — up goes to currently selected plan
    wireDpadNode(
      _continueBtnNode,
      up: _planNodes.isNotEmpty ? _planNodes[selectedIndex] : null,
      lockDown: true,
      lockLeft: true,
      lockRight: true,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitDependentState) {
      _didInitDependentState = true;
      _isPhone = isPhoneWidth(context); // ✅ safe here — deps are attached

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isPhone) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        }
      });
    }
  }

  void _rebuildPlanNodes(int count) {
    // Dispose old nodes before rebuilding.
    for (final n in _planNodes) {
      n.dispose();
    }
    _planNodes.clear();

    for (int i = 0; i < count; i++) {
      final node = FocusNode(debugLabel: 'plan_$i');
      final capturedI = i;
      _planNodes.add(node); // add first so length is correct when wiring
    }

    // Wire after all nodes exist so sibling references are valid.
    for (int i = 0; i < _planNodes.length; i++) {
      final capturedI = i;
      wireDpadNode(
        _planNodes[i],
        up: i > 0 ? _planNodes[i - 1] : _backBtnNode,
        down: i < _planNodes.length - 1 ? _planNodes[i + 1] : _continueBtnNode,
        lockLeft: true,
        lockRight: true,
        onSelect: () {
          setState(() => selectedIndex = capturedI);
          if (capturedI == 0) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
      );
    }

    // Re-wire the static nodes so their dynamic targets (which just changed)
    // are updated to point to the new node instances.
    wireDpadNode(
      _backBtnNode,
      down: _planNodes.isNotEmpty ? _planNodes[0] : null,
      lockUp: true,
      lockLeft: true,
      lockRight: true,
      onSelect: () => GoRouter.of(context).pop(),
    );
    wireDpadNode(
      _continueBtnNode,
      up: _planNodes.isNotEmpty ? _planNodes[selectedIndex] : null,
      lockDown: true,
      lockLeft: true,
      lockRight: true,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _backBtnNode.dispose();
    _continueBtnNode.dispose();
    for (final n in _planNodes) {
      n.dispose();
    }
    _scrollController.dispose();
    // Restore orientation: phones should go back to portrait,
    // TVs/tablets stay unlocked.
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
    return Scaffold(
      backgroundColor: AppColor.background,
      body: BlocConsumer<WiseBloc, WiseState>(
        listener: (context, state) async {
          if (state.status == Status.loading) {
            loader(context);
          } else if (state.status == Status.littleError) {
            stopLoader(context);
            snackBar(context, state.errorMessage);
          } else if (state.status == Status.error) {
            stopLoader(context);
            messageDialog(
              context: context,
              content: CText(state.errorMessage.toString()),
              onTap: () {
                Navigator.of(context).pop();
              },
              okk: "Okk",
            );
          } else {
            stopLoader(context);
            if (state.openPaypallUrl.isNotEmpty) {
              final result = await GoRouter.of(context)
                  .push(PayPalCheckoutScreen.paypalCheckoutScreen);
              final resultMap = result as Map<String, dynamic>?;
              if (resultMap?['status'] == "success") {
                log("Your payement is done-----------");
                snackBar(
                  context,
                  "Your plan has been successfully activated!",
                  Colors.green,
                );
                // Pop with success so the calling screen (TV home) can refresh.
                context.pop({'status': 'success'});
              } else {
                snackBar(context, "Payment not done yet ", Colors.red);
                log("your payment has been failed--------");
              }
            }
          }
        },
        buildWhen: (previous, current) =>
            previous.openPaypallUrl != current.openPaypallUrl,
        builder: (context, state) {
          return Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 2.0,
                colors: [
                  Color(0x15FFB300),
                  AppColor.background,
                  Color(0xFF05070A),
                ],
              ),
            ),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SafeArea(
                child: Builder(
                  builder: (context) {
                    final w = MediaQuery.of(context).size.width;
                    // Responsive horizontal padding — 5% of width, clamped 12–28px
                    final hPad = (w * 0.05).clamp(12.0, 28.0);
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          // ─── Top Bar ───────────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Back button with real focus
                              _FocusableIconButton(
                                focusNode: _backBtnNode,
                                icon: Icons.arrow_back_ios_new_rounded,
                                onTap: () => GoRouter.of(context).pop(),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF59E0B),
                                      Color(0xFFFF8F00),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.workspace_premium_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "PRO",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ─── Premium Crown Header ──────────────────────────────
                          Center(
                            child: AnimatedBuilder(
                              animation: _glowController,
                              builder: (context, child) {
                                return Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFFFFB300).withOpacity(
                                          0.1 + (_glowController.value * 0.08),
                                        ),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFB300)
                                            .withOpacity(
                                              0.08 +
                                                  (_glowController.value *
                                                      0.06),
                                            ),
                                        blurRadius: 40,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          colors: [
                                            Color(0xFFF59E0B),
                                            Color(0xFFFF8F00),
                                          ],
                                        ).createShader(bounds),
                                    child: const Icon(
                                      Icons.workspace_premium_rounded,
                                      size: 56,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ─── Title ─────────────────────────────────────────────
                          Center(
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFF59E0B),
                                  Color(0xFFFDE047),
                                  Color(0xFFF59E0B),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                "Go Premium",
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Center(
                            child: Text(
                              "Unlock all features and enjoy unlimited access",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ─── Feature chips ─────────────────────────────────────
                          Center(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                _buildFeatureChip("Unlimited Streams"),
                                _buildFeatureChip("HD Quality"),
                                _buildFeatureChip("All Devices"),
                                _buildFeatureChip("Priority Support"),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ─── Plan cards ────────────────────────────────────────
                          allplanList.isEmpty
                              ? Center(
                                  child: InkWell(
                                    onTap: () => getPlanData(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColor.surfaceDark.withOpacity(
                                          0.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColor.accentCyan
                                              .withOpacity(0.15),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.refresh_rounded,
                                            color: AppColor.accentCyan
                                                .withOpacity(0.5),
                                            size: 32,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "No Plans Available",
                                            style: TextStyle(
                                              color: AppColor.moreLightGrey
                                                  .withOpacity(0.6),
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Tap to retry",
                                            style: TextStyle(
                                              color: AppColor.accentCyan
                                                  .withOpacity(0.5),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: allplanList.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _buildPlanCard(
                                        model: allplanList[index],
                                        index: index,
                                        focusNode: _planNodes[index],
                                      ),
                                    );
                                  },
                                ),

                          const SizedBox(height: 24),

                          // ─── Continue Button ───────────────────────────────────
                          _ContinueButton(
                            focusNode: _continueBtnNode,
                            enabled: allplanList.isNotEmpty,
                            onPressed: () async {
                              if (_isPhone) {
                                BlocProvider.of<WiseBloc>(context).add(
                                  PaymentEvent(
                                    isLifeTimePayment:
                                        allplanList[selectedIndex].name
                                            .toString(),
                                  ),
                                );
                                log("Lifetime Plan Selected");
                              } else {
                                log("Lifetime Plan Selected on TV");
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => QrCheckoutTvScreen(
                                      planId: allplanList[selectedIndex].name
                                          .toString(),
                                    ),
                                  ),
                                );
                                if (result != null &&
                                    result is Map &&
                                    result['status'] == 'success') {
                                  // If TV checkout is successful, pop this screen so the user returns to the dashboard
                                  if (context.mounted) {
                                    GoRouter.of(context).pop();
                                  }
                                }
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          // ─── Secure payment notice ─────────────────────────────
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: AppColor.moreLightGrey.withOpacity(
                                    0.4,
                                  ),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Secure payment via PayPal",
                                  style: TextStyle(
                                    color: AppColor.moreLightGrey.withOpacity(
                                      0.4,
                                    ),
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ─── D-pad hint ────────────────────────────────────────
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Use arrow keys to navigate · OK to select',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureChip(String text) {
    const Color premiumGold = Color(0xFFFFB300);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: premiumGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: premiumGold.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: premiumGold.withOpacity(0.8),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: premiumGold.withOpacity(0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required AvailablePlanModel model,
    required int index,
    required FocusNode focusNode,
  }) {
    bool isSelected = selectedIndex == index;
    const Color premiumGold = Color(0xFFFFB300);

    return _PlanCard(
      model: model,
      index: index,
      isSelected: isSelected,
      focusNode: focusNode,
      onSelect: () {
        setState(() => selectedIndex = index);
      },
    );
  }

  void getPlanData() async {
    ApiService apiRepo = ApiService();
    await apiRepo
        .hitGetApi(endpoint: "/api/payment/public/plans")
        .then((value) {
          if (value.isSuccess && value.data != null) {
            allplanList = (value.data as List)
                .map(
                  (e) => AvailablePlanModel.fromJson(e as Map<String, dynamic>),
                )
                .toList();
            log("plans loaded: ${allplanList.length}");
            _rebuildPlanNodes(allplanList.length);
            if (!mounted) return;
            setState(() {});
            // Auto-focus the first plan after loading
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _planNodes.isNotEmpty) {
                _planNodes[0].requestFocus();
              }
            });
          } else {
            log("plan data error: ${value.error}");
          }
        })
        .catchError((e) {
          log("plan data error is $e");
        });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Back / icon button with proper focus styling
// ─────────────────────────────────────────────────────────────────────────────
class _FocusableIconButton extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final VoidCallback onTap;

  const _FocusableIconButton({
    required this.focusNode,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_FocusableIconButton> createState() => _FocusableIconButtonState();
}

class _FocusableIconButtonState extends State<_FocusableIconButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isFocused ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: InkWell(
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isFocused
                ? Colors.white.withOpacity(0.15)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isFocused ? const Color(0xFFFFB300) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Icon(
            widget.icon,
            color: _isFocused
                ? const Color(0xFFFFB300)
                : const Color(0xFFFFB300).withOpacity(0.8),
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan card — stateful for focus tracking
// ─────────────────────────────────────────────────────────────────────────────
class _PlanCard extends StatefulWidget {
  final AvailablePlanModel model;
  final int index;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.model,
    required this.index,
    required this.isSelected,
    required this.focusNode,
    required this.onSelect,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
      if (_isFocused) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color premiumGold = Color(0xFFFFB300);
    final isSelected = widget.isSelected;
    final isFocused = _isFocused;

    return AnimatedScale(
      scale: isFocused ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: InkWell(
        focusNode: widget.focusNode,
        onTap: widget.onSelect,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected
                  ? [
                      premiumGold.withOpacity(0.12),
                      premiumGold.withOpacity(0.04),
                    ]
                  : (isFocused
                        ? [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.02),
                          ]
                        : [
                            AppColor.surfaceDark.withOpacity(0.6),
                            AppColor.surfaceDark.withOpacity(0.3),
                          ]),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? premiumGold
                  : (isFocused
                        ? Colors.white70
                        : Colors.white.withOpacity(0.08)),
              width: isSelected || isFocused ? 2 : 1,
            ),
            boxShadow: isSelected || isFocused
                ? [
                    BoxShadow(
                      color: isSelected
                          ? premiumGold.withOpacity(0.15)
                          : Colors.white.withOpacity(0.08),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isFocused
                              ? Colors.white70
                              : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.model.name ?? "",
                      style: TextStyle(
                        color: isSelected || isFocused
                            ? premiumGold
                            : Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (widget.model.description != null &&
                        widget.model.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.model.description!,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white.withOpacity(0.7)
                              : AppColor.moreLightGrey.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: isSelected
                              ? premiumGold.withOpacity(0.7)
                              : AppColor.moreLightGrey.withOpacity(0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${widget.model.durationDays ?? 0} ${widget.model.durationDays == 1 ? "day" : "days"} validity",
                          style: TextStyle(
                            color: isSelected
                                ? premiumGold.withOpacity(0.8)
                                : AppColor.moreLightGrey.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Price column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.model.price.toString(),
                    style: TextStyle(
                      color: isSelected || isFocused
                          ? premiumGold
                          : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    widget.model.currency.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? premiumGold.withOpacity(0.7)
                          : AppColor.moreLightGrey.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue button — stateful for focus tracking
// ─────────────────────────────────────────────────────────────────────────────
class _ContinueButton extends StatefulWidget {
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onPressed;

  const _ContinueButton({
    required this.focusNode,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isFocused ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFFF8F00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFocused ? Colors.white : Colors.transparent,
            width: _isFocused ? 2.5 : 0.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isFocused
                  ? Colors.white.withOpacity(0.5)
                  : const Color(0xFFF59E0B).withOpacity(0.3),
              blurRadius: _isFocused ? 20 : 16,
              spreadRadius: _isFocused ? 2 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          focusNode: widget.focusNode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: widget.enabled ? widget.onPressed : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                "Continue",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
