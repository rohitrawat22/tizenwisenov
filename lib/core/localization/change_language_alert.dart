import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Premium Language Selection dialog — optimized for fast animation on TV/mobile
// BackdropFilter removed (primary jank source). 160ms enter animation.
// ─────────────────────────────────────────────────────────────────────────────

class _Language {
  final String code;
  final String name;
  final String native;
  final String flag;

  const _Language({
    required this.code,
    required this.name,
    required this.native,
    required this.flag,
  });
}

const List<_Language> _supportedLanguages = [
  _Language(code: 'en', name: 'English', native: 'English', flag: '🇬🇧'),
  _Language(code: 'ar', name: 'Arabic', native: 'العربية', flag: '🇸🇦'),
  //_Language(code: 'de', name: 'German', native: 'Deutsch', flag: '🇩🇪'),
  _Language(code: 'es', name: 'Spanish', native: 'Español', flag: '🇪🇸'),
  _Language(code: 'fr', name: 'French', native: 'Français', flag: '🇫🇷'),
  _Language(code: 'hi', name: 'Hindi', native: 'हिंदी', flag: '🇮🇳'),
  _Language(code: 'it', name: 'Italian', native: 'Italiano', flag: '🇮🇹'),
  _Language(code: 'nl', name: 'Dutch', native: 'Nederlands', flag: '🇳🇱'),
  _Language(code: 'pt', name: 'Portuguese', native: 'Português', flag: '🇵🇹'),
];

void showLanguageDialog(BuildContext context) {
  final double screenWidth = MediaQuery.of(context).size.width;
  final double screenHeight = MediaQuery.of(context).size.height;
  final bool isSmallScreen = screenHeight < 500;
  final double hPad = screenWidth < 500
      ? 20.0
      : (screenWidth < 900 ? 24.0 : 40.0);
  final double vPad = isSmallScreen ? 8.0 : 60.0;

  showDialog(
    context: context,
    barrierColor: Colors.black54,
    barrierDismissible: true,
    builder: (context) {
      return _LanguageDialog(
        hPad: hPad,
        vPad: vPad,
        screenHeight: screenHeight,
        isSmallScreen: isSmallScreen,
      );
    },
  );
}

/// Stateful wrapper so we can run the enter animation.
class _LanguageDialog extends StatefulWidget {
  final double hPad;
  final double vPad;
  final double screenHeight;
  final bool isSmallScreen;

  const _LanguageDialog({
    required this.hPad,
    required this.vPad,
    required this.screenHeight,
    required this.isSmallScreen,
  });

  @override
  State<_LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<_LanguageDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scaleAnim = Tween<double>(
      begin: 0.90,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = widget.isSmallScreen;
    final screenHeight = widget.screenHeight;

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: widget.hPad,
            vertical: widget.vPad,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: screenHeight * 0.95,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A0808),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColor.accentRed.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  28,
                  isSmallScreen ? 20 : 32,
                  28,
                  isSmallScreen ? 16 : 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Icon ────────────────────────────────────────────────
                    if (!isSmallScreen)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColor.accentRed.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColor.accentRed.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.language_rounded,
                          color: AppColor.accentRed,
                          size: 36,
                        ),
                      ),

                    if (!isSmallScreen) const SizedBox(height: 20),

                    // ── Title ──────────────────────────────────────────────
                    Text(
                      "Select Language",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 24),

                    // ── Language Options (scrollable + remote navigable) ────
                    Flexible(
                      child: FocusTraversalGroup(
                        policy: WidgetOrderTraversalPolicy(),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _supportedLanguages.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final lang = _supportedLanguages[index];
                            return _RemoteLanguageTile(
                              lang: lang,
                              autofocus: index == 0,
                              isSmallScreen: isSmallScreen,
                              onTap: () {
                                changeLanguage(context, lang.code);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 20),

                    // ── Cancel Button ────────────────────────────────────────
                    _buildCancelButton(context, isSmallScreen),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildCancelButton(BuildContext context, bool isSmallScreen) {
  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => Navigator.pop(context),
    child: Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Text(
        "Cancel",
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Language tile with fast 90ms focus highlight — no AnimatedContainer overhead.
class _RemoteLanguageTile extends StatefulWidget {
  final _Language lang;
  final bool autofocus;
  final bool isSmallScreen;
  final VoidCallback onTap;

  const _RemoteLanguageTile({
    required this.lang,
    required this.onTap,
    required this.isSmallScreen,
    this.autofocus = false,
  });

  @override
  State<_RemoteLanguageTile> createState() => _RemoteLanguageTileState();
}

class _RemoteLanguageTileState extends State<_RemoteLanguageTile> {
  bool hasFocus = false;

  static final Set<LogicalKeyboardKey> _activationKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.gameButtonA,
  };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && _activationKeys.contains(event.logicalKey)) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = widget.isSmallScreen;

    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: _handleKey,
      onFocusChange: (value) {
        if (hasFocus != value) setState(() => hasFocus = value);
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 10 : 14,
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: hasFocus
                ? AppColor.accentRed.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: hasFocus
                  ? AppColor.accentRed.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
              width: hasFocus ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColor.accentRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  widget.lang.flag,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.lang.name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: isSmallScreen ? 15 : 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.lang.native,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: isSmallScreen ? 12 : 13,
                        fontWeight: FontWeight.w400,
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
  }
}

void changeLanguage(BuildContext context, String languageCode) {
  BlocProvider.of<WiseBloc>(context)
      .add(ChangeLanguageEvent(localWord: languageCode));
}
