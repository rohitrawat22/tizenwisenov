import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/end_points.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/api_services/api_services.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/repo/api_repo.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';

class QrCheckoutTvScreen extends StatefulWidget {
  final String planId;
  const QrCheckoutTvScreen({Key? key, required this.planId}) : super(key: key);

  @override
  State<QrCheckoutTvScreen> createState() => _QrCheckoutTvScreenState();
}

class _QrCheckoutTvScreenState extends State<QrCheckoutTvScreen>
    with TickerProviderStateMixin {
  String? _checkoutUrl;
  Timer? _pollingTimer;
  Timer? _countdownTimer;
  bool _isLoading = true;
  String _errorMessage = '';
  int _secondsElapsed = 0;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  final FocusNode _cancelFN = FocusNode(debugLabel: 'cancel_btn');

  static const _kBg = Color(0xFF0D0D12);
  static const _kCard = Color(0xFF14141E);
  static const _kBorder = Color(0xFF2A2A3A);
  bool _isInitialized = false;

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   if (!_isInitialized) {
  //     _isInitialized = true;
  //     _initiateCheckout();
  //   }
  // }

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(
      begin: 0.15,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsElapsed++);
    });

    wireDpadNode(
      _cancelFN,
      lockUp: true,
      lockDown: true,
      lockLeft: true,
      lockRight: true,
      onSelect: () => Navigator.pop(context),
    );

    // Execute after the first frame completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cancelFN.requestFocus();
        _initiateCheckout();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _cancelFN.dispose();
    super.dispose();
  }

  Future<void> _initiateCheckout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final apiService = ApiService();
      final apiRepo = ApiRepo(apiService: apiService);
      final data = await apiRepo.openPaypall(
        isLimeTimePayment: widget.planId,
        endpoints: '/api/payment/checkout',
      );
      setState(() {
        _checkoutUrl = data['checkoutUrl'];
        _isLoading = false;
      });
      _startPollingPaymentStatus();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startPollingPaymentStatus() {
    final apiService = ApiService();
    final apiRepo = ApiRepo(apiService: apiService);
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final invoice = await apiRepo.getPlanInvoice(
          endpoints: '/api/payment/invoice/current?deviceId=$deviceId',
        );
        if (invoice.status != null &&
            (invoice.status!.toUpperCase() == 'COMPLETED' ||
                invoice.status!.toUpperCase() == 'PAID' ||
                invoice.status!.toUpperCase() == 'SUCCESS')) {
          timer.cancel();
          _countdownTimer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Payment Successful! Plan activated.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF2E7D52),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            Navigator.pop(context, {'status': 'success'});
          }
        }
      } catch (e) {
        debugPrint('Polling payment status error: $e');
      }
    });
  }

  String get _elapsedFormatted {
    final m = _secondsElapsed ~/ 60;
    final s = _secondsElapsed % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F0F18), Color(0xFF080810), Color(0xFF030306)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? _buildLoadingState()
                : _errorMessage.isNotEmpty
                ? _buildErrorState()
                : _buildPaymentContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColor.accentRed.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppColor.accentRed.withOpacity(
                      _pulseAnim.value * 0.4,
                    ),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                color: AppColor.accentRed,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Generating Checkout…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we prepare your secure payment link',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE57373).withOpacity(0.1),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFE57373),
              size: 48,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Failed to load checkout',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _buildCancelButton(),
        ],
      ),
    );
  }

  Widget _buildPaymentContent() {
    return Row(
      children: [
        // ── Left panel: instructions ─────────────────────────────
        Expanded(
          flex: 45,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColor.accentRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColor.accentRed.withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.payment_rounded,
                        color: AppColor.accentRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Secure Checkout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'WisePlayer Premium',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // Steps
                _buildStep(
                  1,
                  Icons.phone_android_rounded,
                  'Open Your Phone',
                  'Use any device — phone, tablet or laptop',
                ),
                const SizedBox(height: 20),
                _buildStep(
                  2,
                  Icons.qr_code_scanner_rounded,
                  'Scan the QR Code',
                  'Point your camera at the code on the right',
                ),
                const SizedBox(height: 20),
                _buildStep(
                  3,
                  Icons.lock_rounded,
                  'Complete Payment',
                  'Follow the secure checkout flow',
                ),
                const SizedBox(height: 20),
                _buildStep(
                  4,
                  Icons.check_circle_rounded,
                  'Auto-Activated',
                  'Your plan activates instantly after payment',
                ),

                const Spacer(),

                // Timer
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF4CAF50),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50)
                                    .withOpacity(_pulseAnim.value),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Waiting for payment…',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _elapsedFormatted,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Warning
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Do not close this screen until payment is confirmed.',
                          style: TextStyle(
                            color: Colors.amber.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                _buildCancelButton(),
              ],
            ),
          ),
        ),

        // ── Divider ─────────────────────────────────────────────
        Container(width: 1, color: _kBorder),

        // ── Right panel: QR ─────────────────────────────────────
        Expanded(
          flex: 55,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Headline
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                    children: [
                      TextSpan(
                        text: 'Scan ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'to Pay',
                        style: TextStyle(color: AppColor.accentRed),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Open your camera app and point it at the code below',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // QR code with animated glow
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, child) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColor.accentRed.withOpacity(
                            _glowAnim.value,
                          ),
                          blurRadius: 50,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColor.accentRed.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: _checkoutUrl ?? '',
                      version: QrVersions.auto,
                      size: 220.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFFB71C1C),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // URL hint
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link_rounded,
                        color: Colors.white.withOpacity(0.4),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'wise-player.com/pay',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(int num, IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColor.accentRed.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColor.accentRed.withOpacity(0.35)),
          ),
          child: Center(
            child: Text(
              '$num',
              style: const TextStyle(
                color: AppColor.accentRed,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white.withOpacity(0.7), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return Focus(
      focusNode: _cancelFN,
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                color: focused
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: focused
                      ? Colors.white.withOpacity(0.6)
                      : Colors.white.withOpacity(0.12),
                  width: focused ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white.withOpacity(0.7),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
