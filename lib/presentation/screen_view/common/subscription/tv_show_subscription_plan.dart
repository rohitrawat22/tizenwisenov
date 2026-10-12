// ─────────────────────────────────────────────────────────────────────────────
// tv_show_subscription_plan.dart
//
// Premium plan selection screen for Android TV / Google TV.
// Theme: Matches WisePlayerTVHomeScreen exactly —
//   • Same dark obsidian gradient (#0F0F18 → #030306)
//   • Maroon (#800000) accent with #E57373 highlights
//   • Card surface #161620, border #2A2A3A
//   • Same focus treatment: maroon glow + scale-up
//   • Full D-pad navigation, BlocConsumer for checkout
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/localization/generated/l10n.dart';
import 'package:wiseplayertizen/core/utils/breakpoints.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';
import 'package:wiseplayertizen/core/utils/loader.dart';
import 'package:wiseplayertizen/core/utils/message_dialog.dart';
import 'package:wiseplayertizen/core/utils/snackbar.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/pay_pal_chekout_screen.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/qr_checkout_tv_screen.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/subscription/plan.model.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';

// ── Brand constants (identical to wise_player_tv_home_screen.dart) ────────────
const _kRed = Color(0xFF800000); // Maroon brand red
const _kRedL = Color(0xFFE57373); // Light red highlight
const _kCard = Color(0xFF161620); // Card surface
const _kBorder = Color(0xFF2A2A3A); // Subtle border
const double _kSafe = 40.0; // TV overscan padding

// ─────────────────────────────────────────────────────────────────────────────

class TVSubscriptionPlanScreen extends StatefulWidget {
  const TVSubscriptionPlanScreen({super.key});

  @override
  State<TVSubscriptionPlanScreen> createState() =>
      _TVSubscriptionPlanScreenState();
}

class _TVSubscriptionPlanScreenState extends State<TVSubscriptionPlanScreen>
    with TickerProviderStateMixin {
  // ── Animations ───────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  // ── Focus graph ──────────────────────────────────────────────────────────
  final FocusNode _backFN = FocusNode(debugLabel: 'sub_back');
  final FocusNode _continueFN = FocusNode(debugLabel: 'sub_continue');
  final List<FocusNode> _planFNs = [];
  final ScrollController _scroll = ScrollController();

  // ── State ────────────────────────────────────────────────────────────────
  int _selected = 0;
  List<AvailablePlanModel> _plans = [];

  // Captured in initState() so it remains valid in dispose() — where the
  // widget element is deactivated and MediaQuery lookups are unsafe.
  late final bool _isPhone;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Pulsing animation for the shield icon
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Ambient glow animation for the header
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(
      begin: 0.15,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _wireBackFN();
    _wireContinueFN();
    _fetchPlans();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe to read inherited widgets here
    _isPhone = isPhoneWidth(context);
  }

  void _wireBackFN() {
    wireDpadNode(
      _backFN,
      down: _planFNs.isNotEmpty ? _planFNs[0] : _continueFN,
      right: _planFNs.isNotEmpty ? _planFNs[0] : null,
      lockUp: true,
      lockLeft: true,
      onSelect: () => GoRouter.of(context).pop(),
    );
  }

  void _wireContinueFN() {
    wireDpadNode(
      _continueFN,
      up: _planFNs.isNotEmpty ? _planFNs[_selected] : _backFN,
      lockDown: true,
      lockLeft: true,
      lockRight: true,
      onSelect: _onContinue,
    );
  }

  void _rebuildPlanNodes(int count) {
    for (final n in _planFNs) n.dispose();
    _planFNs.clear();
    for (int i = 0; i < count; i++) {
      final node = FocusNode(debugLabel: 'plan_$i');
      final idx = i;
      wireDpadNode(
        node,
        up: idx > 0 ? null : _backFN, // null for non-first handled below
        down: idx < count - 1
            ? null
            : _continueFN, // null for non-last handled below
        left: _backFN,
        lockRight: true,
        onSelect: () => setState(() => _selected = idx),
      );
      // Override up/down with index-aware targets after all nodes are built.
      // We re-wire after the loop using a post-build step — but since
      // _planFNs is populated sequentially, we can re-call wireDpadNode
      // after the list is complete in a post-frame callback.
      _planFNs.add(node);
    }
    // Re-wire all plan nodes now that _planFNs is fully populated,
    // so up/down references to adjacent nodes are always valid.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (int i = 0; i < _planFNs.length; i++) {
        wireDpadNode(
          _planFNs[i],
          up: i > 0 ? _planFNs[i - 1] : _backFN,
          down: i < _planFNs.length - 1 ? _planFNs[i + 1] : _continueFN,
          left: _backFN,
          lockRight: true,
          onSelect: () {
            setState(() => _selected = i);
            if (_scroll.hasClients) {
              _scroll.animateTo(
                i * 120.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          },
        );
      }
      // Re-wire back/continue now that _planFNs are known.
      _wireBackFN();
      _wireContinueFN();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _backFN.dispose();
    _continueFN.dispose();
    for (final n in _planFNs) n.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  void _fetchPlans() async {
    try {
      final res = await ApiService().hitGetApi(
        endpoint: '/api/payment/public/plans',
      );
      if (res.isSuccess && res.data != null) {
        _plans = (res.data as List)
            .map((e) => AvailablePlanModel.fromJson(e as Map<String, dynamic>))
            .toList();
        log('TV plans loaded: ${_plans.length}');
        _rebuildPlanNodes(_plans.length);
        if (!mounted) return;
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _planFNs.isNotEmpty) _planFNs[0].requestFocus();
        });
      } else {
        log('TV plans load error: ${res.error}');
      }
    } catch (e) {
      log('TV plans exception: $e');
    }
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  void _onContinue() {
    if (_plans.isEmpty) return;
    if (_isPhone) {
      BlocProvider.of<WiseBloc>(
        context,
      ).add(PaymentEvent(isLifeTimePayment: _plans[_selected].name.toString()));
    } else {
      _launchTVCheckout();
    }
  }

  Future<void> _launchTVCheckout() async {
    print("dasasedsadsa${_plans[_selected].id.toString()}");
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QrCheckoutTvScreen(planId: _plans[_selected].id.toString()),
      ),
    );
    if (result is Map && result['status'] == 'success' && mounted) {
      GoRouter.of(context).pop();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
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
                onTap: () => Navigator.of(context).pop(),
                okk: 'Okk',
              );
            } else {
              stopLoader(context);
              if (state.openPaypallUrl.isNotEmpty) {
                final result = await GoRouter.of(context)
                    .push(PayPalCheckoutScreen.paypalCheckoutScreen);
                final resultMap = result as Map<String, dynamic>?;
                if (resultMap?['status'] == 'success') {
                  snackBar(
                    context,
                    'Your plan has been successfully activated. Please refresh the page.',
                    Colors.green,
                  );
                  if (mounted) context.pop();
                } else {
                  snackBar(context, 'Payment not completed yet.', Colors.red);
                }
              }
            }
          },
          buildWhen: (p, c) => p.openPaypallUrl != c.openPaypallUrl,
          builder: (context, state) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F0F18),
                    Color(0xFF080810),
                    Color(0xFF030306),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;
                    // Responsive padding — 40 for TV overscan, smaller for phones
                    final safePad = isWide
                        ? _kSafe
                        : (constraints.maxWidth < 400 ? 12.0 : 20.0);

                    if (isWide) {
                      // ── TV / Tablet: side-by-side, fills available height ──
                      return Padding(
                        padding: EdgeInsets.all(safePad),
                        child: Column(
                          children: [
                            // ── Top bar ──
                            _buildTopBar(s),
                            const SizedBox(height: 24),
                            // ── Main two-column content ──
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left: branding + features
                                  Expanded(flex: 48, child: _buildLeftPanel(s)),
                                  const SizedBox(width: 28),
                                  // Right: plan cards + continue
                                  Expanded(
                                    flex: 52,
                                    child: _buildRightPanel(s),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // ── Phone / small screen: single column scrollable ──
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: safePad,
                          vertical: safePad * 0.6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopBar(s),
                            const SizedBox(height: 20),
                            _buildLeftPanel(s),
                            const SizedBox(height: 20),
                            // Right panel without Expanded (no bounded height needed)
                            _buildRightPanelScrollable(s),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(S s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _kRed.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          _SubFocusButton(
            focusNode: _backFN,
            onPressed: () => GoRouter.of(context).pop(),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Title
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              children: [
                TextSpan(
                  text: 'Wise ',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: 'Player',
                  style: TextStyle(color: _kRed),
                ),
              ],
            ),
          ),
          Text(
            '  ·  ${s.goPremium}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          const Spacer(),

          // Premium badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _kRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kRed.withOpacity(0.4), width: 1.2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, color: _kRedL, size: 16),
                SizedBox(width: 6),
                Text(
                  'PRO',
                  style: TextStyle(
                    color: _kRedL,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Left Panel ────────────────────────────────────────────────────────────

  Widget _buildLeftPanel(S s) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Animated shield/premium icon with maroon glow
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kRed.withOpacity(0.15 + _glowAnim.value * 0.15),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _kRed.withOpacity(0.2 + _glowAnim.value * 0.2),
                    blurRadius: 28,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kRed.withOpacity(0.2),
                    border: Border.all(
                      color: _kRedL.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: _kRedL,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Title — gradient matches home screen maroon tones
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFE57373), Colors.white, Color(0xFFE57373)],
            ).createShader(bounds),
            child: Text(
              s.goPremium,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            s.premiumDesc,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 13,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Feature list
          _buildFeatureRow(Icons.all_inclusive_rounded, 'Unlimited Streams'),
          const SizedBox(height: 10),
          _buildFeatureRow(Icons.hd_rounded, 'HD Quality'),
          const SizedBox(height: 10),
          _buildFeatureRow(Icons.devices_rounded, 'All Devices'),
          const SizedBox(height: 10),
          _buildFeatureRow(Icons.support_agent_rounded, 'Priority Support'),
        ],
      ),
    );
  }

  // ── Feature row ───────────────────────────────────────────────────────────

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _kRed.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kRed.withOpacity(0.25)),
          ),
          child: Icon(icon, color: _kRedL, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ── Right Panel ───────────────────────────────────────────────────────────

  Widget _buildRightPanel(S s) {
    return Column(
      children: [
        // Section header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _kRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kRed.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.view_list_rounded, color: _kRedL, size: 16),
              const SizedBox(width: 8),
              Text(
                'AVAILABLE PLANS',
                style: TextStyle(
                  color: _kRedL.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              // Active plan count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_plans.length}',
                  style: const TextStyle(
                    color: _kRedL,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Plans list
        Expanded(
          child: _plans.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulsing loading indicator
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Icon(
                            Icons.hourglass_top_rounded,
                            color: _kRedL.withOpacity(_pulseAnim.value),
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Loading plans…',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Fetching subscription options',
                          style: TextStyle(
                            color: _kRedL.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  itemCount: _plans.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SubPlanCard(
                      model: _plans[i],
                      index: i,
                      isSelected: _selected == i,
                      focusNode: _planFNs[i],
                      onSelect: () => setState(() => _selected = i),
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 16),

        // Continue button
        _SubContinueButton(
          focusNode: _continueFN,
          enabled: _plans.isNotEmpty,
          onPressed: _onContinue,
        ),
      ],
    );
  }

  // ── Right Panel (scrollable / phone variant — no Expanded) ─────────────────

  Widget _buildRightPanelScrollable(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _kRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kRed.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.view_list_rounded, color: _kRedL, size: 16),
              const SizedBox(width: 8),
              Text(
                'AVAILABLE PLANS',
                style: TextStyle(
                  color: _kRedL.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_plans.length}',
                  style: const TextStyle(
                    color: _kRedL,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Plans list — shrinkWrap so it works in a scroll view
        _plans.isEmpty
            ? Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 28,
                  ),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Icon(
                          Icons.hourglass_top_rounded,
                          color: _kRedL.withOpacity(_pulseAnim.value),
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Loading plans…',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Fetching subscription options',
                        style: TextStyle(
                          color: _kRedL.withOpacity(0.5),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _plans.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubPlanCard(
                    model: _plans[i],
                    index: i,
                    isSelected: _selected == i,
                    focusNode: _planFNs[i],
                    onSelect: () => setState(() => _selected = i),
                  ),
                ),
              ),

        const SizedBox(height: 16),

        // Continue button
        _SubContinueButton(
          focusNode: _continueFN,
          enabled: _plans.isNotEmpty,
          onPressed: _onContinue,
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubFocusButton — Back button with maroon focus glow
// ─────────────────────────────────────────────────────────────────────────────

class _SubFocusButton extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final Widget child;

  const _SubFocusButton({
    required this.focusNode,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedScale(
              scale: focused ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: focused
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: focused ? _kRedL : Colors.white.withOpacity(0.1),
                    width: focused ? 2.0 : 1.0,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color: _kRed.withOpacity(0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SubPlanCard — Maroon-themed plan card with focus glow
// ─────────────────────────────────────────────────────────────────────────────

class _SubPlanCard extends StatefulWidget {
  final AvailablePlanModel model;
  final int index;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onSelect;

  const _SubPlanCard({
    required this.model,
    required this.index,
    required this.isSelected,
    required this.focusNode,
    required this.onSelect,
  });

  @override
  State<_SubPlanCard> createState() => _SubPlanCardState();
}

class _SubPlanCardState extends State<_SubPlanCard> {
  bool _focused = false;

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
    if (!mounted) return;
    setState(() => _focused = widget.focusNode.hasFocus);
    if (_focused) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;
    final foc = _focused;

    // Colors adapt based on selected/focused state
    final borderColor = sel
        ? _kRedL
        : foc
        ? _kRedL.withOpacity(0.7)
        : _kBorder;
    final bgColor = sel
        ? _kRed.withOpacity(0.15)
        : foc
        ? Colors.white.withOpacity(0.06)
        : _kCard;

    return AnimatedScale(
      scale: foc ? 1.025 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: InkWell(
        focusNode: widget.focusNode,
        onTap: widget.onSelect,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: sel || foc ? 2.0 : 1.0,
            ),
            boxShadow: sel || foc
                ? [
                    BoxShadow(
                      color: _kRed.withOpacity(sel ? 0.3 : 0.2),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Radio indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? _kRed : Colors.transparent,
                  border: sel
                      ? null
                      : Border.all(
                          color: foc
                              ? _kRedL.withOpacity(0.6)
                              : Colors.white.withOpacity(0.25),
                          width: 2,
                        ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: _kRed.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: sel
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 16),

              // Plan name + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.model.name ?? '',
                      style: TextStyle(
                        color: sel || foc ? _kRedL : Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (widget.model.description != null &&
                        widget.model.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.model.description!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: sel
                              ? _kRedL.withOpacity(0.7)
                              : Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.model.durationDays ?? 0} '
                          '${widget.model.durationDays == 1 ? "day" : "days"} validity',
                          style: TextStyle(
                            color: sel
                                ? _kRedL.withOpacity(0.7)
                                : Colors.white.withOpacity(0.35),
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
                    widget.model.price?.toString() ?? '',
                    style: TextStyle(
                      color: sel || foc ? _kRedL : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    widget.model.currency?.toString() ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
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
// _SubContinueButton — Maroon gradient CTA
// ─────────────────────────────────────────────────────────────────────────────

class _SubContinueButton extends StatefulWidget {
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onPressed;

  const _SubContinueButton({
    required this.focusNode,
    required this.enabled,
    required this.onPressed,
  });

  @override
  State<_SubContinueButton> createState() => _SubContinueButtonState();
}

class _SubContinueButtonState extends State<_SubContinueButton> {
  bool _focused = false;

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
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _focused ? 1.03 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF800000), Color(0xFFB71C1C)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focused ? _kRedL : Colors.transparent,
            width: _focused ? 2.5 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: _focused
                  ? _kRedL.withOpacity(0.5)
                  : _kRed.withOpacity(0.3),
              blurRadius: _focused ? 24 : 12,
              spreadRadius: _focused ? 3 : 0,
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
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: widget.enabled ? widget.onPressed : null,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Continue to Checkout',
                style: TextStyle(
                  fontSize: 16,
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
