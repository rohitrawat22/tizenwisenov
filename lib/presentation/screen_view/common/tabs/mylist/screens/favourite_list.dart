import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/utils/dpad_focus_graph.dart';
import 'package:wiseplayertizen/core/widgets/cached_image.dart';

import 'package:wiseplayertizen/data/local_storage/hive_service.dart';
import 'package:wiseplayertizen/data/models/fav.mode.dart';
import 'package:wiseplayertizen/presentation/screen_view/common/fav/fav.video.dart';

class FavouriteScreen extends StatefulWidget {
  static const String routeName = '/favourites';
  const FavouriteScreen({super.key});

  @override
  State<FavouriteScreen> createState() => _FavouriteScreenState();
}

class _FavouriteScreenState extends State<FavouriteScreen> {
  List<FavModel> favList = [];
  bool isLoading = true;

  // Focus nodes for the action buttons in the AppBar area
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'fav_back');
  final FocusNode _clearFocusNode = FocusNode(debugLabel: 'fav_clear_all');

  // Focus nodes pool for list items
  final Map<int, List<FocusNode>> _itemFocusNodes = {};

  List<FocusNode> _nodesForItem(int index) {
    if (!_itemFocusNodes.containsKey(index)) {
      final playNode = FocusNode(debugLabel: 'fav_play_$index');
      final removeNode = FocusNode(debugLabel: 'fav_remove_$index');
      _itemFocusNodes[index] = [playNode, removeNode];
    }
    return _itemFocusNodes[index]!;
  }

  @override
  void initState() {
    super.initState();
    _loadFavourites();

    // Use shared wireDpadNode helper for static bar buttons.
    wireDpadNode(
      _clearFocusNode,
      left: _backFocusNode,
      lockUp: true,
      lockRight: true,
      lockDown: true,
      onSelect: _clearAllFav,
    );

    wireDpadNode(
      _backFocusNode,
      lockUp: true,
      lockLeft: true,
      onSelect: () => Navigator.of(context).pop(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _backFocusNode.requestFocus();
    });
  }

  /// Re-wire the static app-bar buttons after favList changes so
  /// right-arrow from back → clear and down-arrow → first item remain correct.
  void _wireBarButtons() {
    wireDpadNode(
      _backFocusNode,
      right: favList.isNotEmpty ? _clearFocusNode : null,
      down: favList.isNotEmpty ? _nodesForItem(0)[0] : null,
      lockUp: true,
      lockLeft: true,
      onSelect: () => Navigator.of(context).pop(),
    );
  }

  /// Wire the entire D-pad focus graph for all current list items.
  /// Called only when [favList] changes — never inside itemBuilder.
  void _wireFocusGraph() {
    for (int index = 0; index < favList.length; index++) {
      final nodes = _nodesForItem(index);
      final playNode = nodes[0];
      final removeNode = nodes[1];
      final fav = favList[index];

      wireDpadNode(
        playNode,
        right: removeNode,
        up: index == 0 ? _backFocusNode : _nodesForItem(index - 1)[0],
        down: index < favList.length - 1 ? _nodesForItem(index + 1)[0] : null,
        lockDown: index == favList.length - 1,
        lockLeft: true,
        onSelect: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FavVideoPlayerScreen(favItem: fav),
            ),
          ).then((_) {
            if (mounted) _loadFavourites();
          });
        },
      );

      wireDpadNode(
        removeNode,
        left: playNode,
        up: index == 0 ? _clearFocusNode : _nodesForItem(index - 1)[1],
        down: index < favList.length - 1 ? _nodesForItem(index + 1)[1] : null,
        lockDown: index == favList.length - 1,
        lockRight: true,
        onSelect: () => _removeFav(fav),
      );
    }
  }

  @override
  void dispose() {
    _backFocusNode.dispose();
    _clearFocusNode.dispose();
    for (final nodes in _itemFocusNodes.values) {
      for (final n in nodes) {
        n.dispose();
      }
    }
    _itemFocusNodes.clear();
    super.dispose();
  }

  // ── Focus-node cache invalidation ────────────────────────────────────────
  //
  // Call this BEFORE any setState that changes favList's length or order.
  // If a focused node is about to be disposed, hand focus to _backFocusNode
  // via a post-frame callback so the remote is never left without a target.
  void _invalidateItemFocusNodes() {
    final bool hadFocusInside = _itemFocusNodes.values.any(
      (nodes) => nodes.any((n) => n.hasFocus),
    );
    for (final nodes in _itemFocusNodes.values) {
      for (final n in nodes) {
        n.dispose();
      }
    }
    _itemFocusNodes.clear();
    if (hadFocusInside) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _backFocusNode.requestFocus();
      });
    }
  }

  Future<void> _loadFavourites() async {
    if (!mounted) return;
    _invalidateItemFocusNodes(); // dispose stale nodes before list changes
    setState(() => isLoading = true);
    final data = HiveService.getFavList();
    if (mounted) {
      setState(() {
        favList = data;
        isLoading = false;
      });
      _wireBarButtons();
      _wireFocusGraph(); // wire all item nodes after list is set
    }
  }

  Future<void> _removeFav(FavModel fav) async {
    await HiveService.deleteFav(fav.id);
    if (!mounted) return;
    _invalidateItemFocusNodes(); // dispose before list shrinks
    setState(() => favList.removeWhere((item) => item.id == fav.id));
    _wireBarButtons();
    _wireFocusGraph(); // re-wire after list shrinks
    _showToast('${fav.title} removed from favourites', isError: true);
  }

  Future<void> _clearAllFav() async {
    final confirm = await _showClearAllDialog();
    if (confirm == true) {
      await HiveService.clearAll();
      if (!mounted) return;
      _invalidateItemFocusNodes(); // dispose before list empties
      setState(() => favList.clear());
      _wireBarButtons();
      // No need to call _wireFocusGraph() — list is empty
    }
  }

  Future<bool?> _showClearAllDialog() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _PremiumConfirmDialog(
        title: 'Clear All Favourites',
        message: 'This will remove all your saved favourites. This cannot be undone.',
        confirmLabel: 'Clear All',
        cancelLabel: 'Keep',
        isDangerous: true,
      ),
    );
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.favorite_border : Icons.favorite,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFF7F0000)
            : const Color(0xFF1B5E20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.8),
            radius: 1.4,
            colors: [
              AppColor.accentRed.withValues(alpha: 0.10),
              const Color(0xFF0A0A12),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Custom AppBar ──────────────────────────────────────────
              _buildAppBar(isTV),

              // ── Body ──────────────────────────────────────────────────
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColor.accentRed,
                        ),
                      )
                    : favList.isEmpty
                    ? _buildEmptyState()
                    : _buildFavList(isTV),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isTV) {
    return Container(
      height: isTV ? 64 : 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Back button
          _AppBarButton(
            focusNode: _backFocusNode,
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),

          const SizedBox(width: 14),

          // Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColor.accentRed.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColor.accentRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Favourites',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (favList.isNotEmpty)
                    Text(
                      '${favList.length} saved',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Clear all button
          if (favList.isNotEmpty)
            _AppBarButton(
              focusNode: _clearFocusNode,
              icon: Icons.delete_sweep_rounded,
              label: 'Clear All',
              onTap: _clearAllFav,
              isDestructive: true,
              tooltip: 'Remove all favourites',
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const _FavEmptyState();
  }

  Widget _buildFavList(bool isTV) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: favList.length,
      itemBuilder: (context, index) {
        final fav = favList[index];
        final nodes = _nodesForItem(index);
        final playNode = nodes[0];
        final removeNode = nodes[1];

        // Focus graph is wired in _wireFocusGraph() which runs only when
        // favList changes — NOT on every scroll/build frame.
        return _FavItemCard(
          fav: fav,
          index: index,
          total: favList.length,
          playNode: playNode,
          removeNode: removeNode,
          onPlay: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FavVideoPlayerScreen(favItem: fav),
              ),
            ).then((_) {
              if (mounted) _loadFavourites();
            });
          },
          onRemove: () => _removeFav(fav),
        );
      },
    );
  }
}

// ─── Extracted StatelessWidgets ───────────────────────────────────────────

class _FavEmptyState extends StatelessWidget {
  const _FavEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColor.accentRed.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: AppColor.accentRed.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              size: 60,
              color: AppColor.accentRed.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Favourites Yet',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save streams from the dashboard\nand they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppBar icon button with D-pad focus
// ─────────────────────────────────────────────────────────────────────────────
class _AppBarButton extends StatefulWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool isDestructive;
  final String? tooltip;

  const _AppBarButton({
    required this.focusNode,
    required this.icon,
    required this.onTap,
    this.label,
    this.isDestructive = false,
    this.tooltip,
  });

  @override
  State<_AppBarButton> createState() => _AppBarButtonState();
}

class _AppBarButtonState extends State<_AppBarButton> {
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
    final accent = widget.isDestructive ? AppColor.accentRed : Colors.white;
    return Tooltip(
      message: widget.tooltip ?? '',
      child: AnimatedScale(
        scale: _isFocused ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: InkWell(
          focusNode: widget.focusNode,
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(
              horizontal: widget.label != null ? 12 : 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _isFocused
                  ? accent.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused
                    ? accent.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.08),
                width: _isFocused ? 1.8 : 1.0,
              ),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.25),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: _isFocused
                      ? accent
                      : Colors.white.withValues(alpha: 0.7),
                  size: 20,
                ),
                if (widget.label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.label!,
                    style: TextStyle(
                      color: _isFocused
                          ? accent
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single favourite item card — D-pad focusable play area + remove button
// ─────────────────────────────────────────────────────────────────────────────
class _FavItemCard extends StatefulWidget {
  final FavModel fav;
  final int index;
  final int total;
  final FocusNode playNode;
  final FocusNode removeNode;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _FavItemCard({
    required this.fav,
    required this.index,
    required this.total,
    required this.playNode,
    required this.removeNode,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  State<_FavItemCard> createState() => _FavItemCardState();
}

class _FavItemCardState extends State<_FavItemCard> {
  bool _playFocused = false;
  bool _removeFocused = false;

  @override
  void initState() {
    super.initState();
    widget.playNode.addListener(_rebuild);
    widget.removeNode.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) {
      setState(() {
        _playFocused = widget.playNode.hasFocus;
        _removeFocused = widget.removeNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    widget.playNode.removeListener(_rebuild);
    widget.removeNode.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAnyFocused = _playFocused || _removeFocused;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _playFocused
              ? Colors.white.withValues(alpha: 0.7)
              : (_removeFocused
                    ? AppColor.accentRed.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.06)),
          width: isAnyFocused ? 2.0 : 1.0,
        ),
        boxShadow: isAnyFocused
            ? [
                BoxShadow(
                  color: (_playFocused ? Colors.white : AppColor.accentRed)
                      .withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAnyFocused
                  ? [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.04),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.04),
                      Colors.white.withValues(alpha: 0.02),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              // ── Play tap area ──────────────────────────────────────
              Expanded(
                child: InkWell(
                  focusNode: widget.playNode,
                  onTap: widget.onPlay,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Thumbnail
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedImage(
                                imageUrl: widget.fav.photoImage,
                                width: 100,
                                height: 65,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (_playFocused)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(width: 14),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.fav.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _playFocused
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (widget.fav.isLive
                                                  ? AppColor.accentRed
                                                  : Colors.blueGrey)
                                              .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color:
                                            (widget.fav.isLive
                                                    ? AppColor.accentRed
                                                    : Colors.blueGrey)
                                                .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      widget.fav.isLive ? 'LIVE' : 'MOVIE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: widget.fav.isLive
                                            ? AppColor.accentRed
                                            : Colors.blueGrey[200],
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ID: ${widget.fav.id}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Divider ────────────────────────────────────────────
              Container(
                width: 1,
                height: 52,
                color: Colors.white.withValues(alpha: 0.08),
              ),

              // ── Remove button ──────────────────────────────────────
              InkWell(
                focusNode: widget.removeNode,
                onTap: widget.onRemove,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(16),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 60,
                  constraints: const BoxConstraints(minHeight: 89),
                  decoration: BoxDecoration(
                    color: _removeFocused
                        ? AppColor.accentRed.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: _removeFocused
                            ? AppColor.accentRed
                            : AppColor.accentRed.withValues(alpha: 0.5),
                        size: _removeFocused ? 24 : 20,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Remove',
                        style: TextStyle(
                          color: _removeFocused
                              ? AppColor.accentRed
                              : Colors.white.withValues(alpha: 0.3),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium confirm dialog (shared)
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDangerous;

  const _PremiumConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.isDangerous = false,
  });

  @override
  State<_PremiumConfirmDialog> createState() => _PremiumConfirmDialogState();
}

class _PremiumConfirmDialogState extends State<_PremiumConfirmDialog> {
  final FocusNode _cancelNode = FocusNode(debugLabel: 'conf_cancel');
  final FocusNode _confirmNode = FocusNode(debugLabel: 'conf_confirm');

  @override
  void initState() {
    super.initState();

    _cancelNode.onKeyEvent = (node, event) {
      if (event is! KeyUpEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _confirmNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    _confirmNode.onKeyEvent = (node, event) {
      if (event is! KeyUpEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _cancelNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cancelNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelNode.dispose();
    _confirmNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0808),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColor.accentRed.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColor.accentRed.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColor.accentRed.withValues(alpha: 0.4),
                ),
              ),
              child: const Icon(
                Icons.delete_sweep_rounded,
                color: AppColor.accentRed,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              widget.message,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: _buildBtn(
                    focusNode: _cancelNode,
                    label: widget.cancelLabel,
                    isPrimary: false,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBtn(
                    focusNode: _confirmNode,
                    label: widget.confirmLabel,
                    isPrimary: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn({
    required FocusNode focusNode,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return _DialogBtn(
      focusNode: focusNode,
      label: label,
      isPrimary: isPrimary,
      onTap: onTap,
    );
  }
}

class _DialogBtn extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _DialogBtn({
    required this.focusNode,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> {
  bool _f = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _f = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusNode: widget.focusNode,
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: 48,
        decoration: BoxDecoration(
          color: _f
              ? (widget.isPrimary
                    ? AppColor.accentRed
                    : Colors.white.withValues(alpha: 0.14))
              : (widget.isPrimary
                    ? AppColor.accentRed.withValues(alpha: 0.20)
                    : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _f
                ? Colors.white
                : (widget.isPrimary
                      ? AppColor.accentRed.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.1)),
            width: _f ? 2.0 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              color: _f ? Colors.white : Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
