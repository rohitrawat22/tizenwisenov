import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wiseplayertizen/core/colors/colors.dart';
import 'package:wiseplayertizen/core/widgets/custom_text.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/channel_model.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/wise_bloc.dart';

class Channels extends StatefulWidget {
  final bool isForMobile;
  final String urlTillChannel;
  const Channels({
    super.key,
    required this.urlTillChannel,
    this.isForMobile = false,
  });

  @override
  State<Channels> createState() => _ChannelsState();
}

class _ChannelsState extends State<Channels> {
  final ScrollController _scrollController = ScrollController();
  bool _hasInitialFocusBeenSet = false;

  // Focus node for the first item — ensures default focus on load.
  // Using a single persistent FocusNode for index 0 means we can safely
  // call requestFocus() on it at any time without risk of a stale node.
  final FocusNode _firstItemFocus = FocusNode(debugLabel: 'channel_0');

  void goToSelectedChannel(int index) {
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // Use itemExtent * index for pixel-perfect positioning.
      // jumpTo (not animateTo) so focus and scroll land at the same frame.
      final double position = (index * 96.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(position);
    });
  }

  @override
  void initState() {
    super.initState();
    final state = context.read<WiseBloc>().state;
    final List<ChannelModel> categoriesList = state.filterChannelsList;
    final int selectedIndex = categoriesList.indexWhere(
      (e) => e.categoryId == state.selectedChannel?.categoryId,
    );
    goToSelectedChannel(selectedIndex);

    // Request focus on the first item after the first frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstItemFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstItemFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WiseBloc, WiseState>(
      buildWhen: (previous, current) =>
          previous.filterChannelsList != current.filterChannelsList ||
          previous.selectedChannel?.categoryId !=
              current.selectedChannel?.categoryId,
      listener: (context, state) {
        final List<ChannelModel> categoriesList = state.filterChannelsList;
        final int selectedIndex = categoriesList.indexWhere(
          (e) => e.categoryId == state.selectedChannel?.categoryId,
        );
        goToSelectedChannel(selectedIndex);

        // Only focus the first item on the very first data load, not on
        // every category switch. Requesting focus on every select causes
        // the sidebar to "freeze" on index 0 when you tap a lower item.
        if (categoriesList.isNotEmpty && !_hasInitialFocusBeenSet) {
          _hasInitialFocusBeenSet = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _firstItemFocus.requestFocus();
          });
        }
      },
      builder: (context, state) {
        final List<ChannelModel> categoriesList = state.filterChannelsList;
        return categoriesList.isEmpty
            ? Center(child: CText("No Categories Found", color: Colors.grey))
            : ListView.builder(
                controller: _scrollController,
                itemExtent:
                    96, // Fixed height for O(1) scrolling (84 + margin 6*2)
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: categoriesList.length,
                itemBuilder: (context, index) {
                  ChannelModel data = categoriesList[index];
                  bool isSelected =
                      state.selectedChannel?.categoryId == data.categoryId;

                  // Use the shared first-item focus node for index 0,
                  // otherwise create an ephemeral node (managed by Focus widget internally).
                  return Focus(
                    autofocus: index == 0,
                    focusNode: index == 0 ? _firstItemFocus : null,
                    // Handle D-pad select/enter directly on the Focus widget
                    // so we don't need to bubble up through InkWell → Material
                    // → Container for every keypress. This eliminates the
                    // 1-frame delay that felt like a "freeze" on first tap.
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          (event.logicalKey == LogicalKeyboardKey.select ||
                              event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey == LogicalKeyboardKey.space)) {
                        final bloc = context.read<WiseBloc>();
                        final currentState = bloc.state;
                        if (currentState.selectedChannel?.categoryId !=
                            data.categoryId) {
                          if (data.categoryId == "favorites_category") {
                            bloc.add(
                              SelectedChannelEvent(selectedChannel: data),
                            );
                          } else {
                            bloc.add(
                              VideosOnPerticulerChannelEvent(
                                channelId: data.categoryId!,
                                urlTillChannel: widget.urlTillChannel,
                                isStopLoader: false,
                              ),
                            );
                            bloc.add(
                              SelectedChannelEvent(selectedChannel: data),
                            );
                          }
                        }
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Builder(
                      builder: (context) {
                        final isFocused = Focus.of(context).hasFocus;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 84,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isFocused
                                  ? AppColor.coralRed
                                  : (isSelected
                                        ? AppColor.coralRedOpacity50
                                        : AppColor.whiteOpacity10),
                              width: isFocused ? 2.5 : 1,
                            ),
                            // PERF: BoxShadow only for focused/selected item.
                            // Every idle row had a blurred shadow painting
                            // every frame \u2014 removed to save GPU on low-end TVs.
                            boxShadow: isFocused || isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColor.coralRed.withOpacity(0.4),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: isFocused
                                  ? AppColor.coralRedGradientFocused
                                  : (isSelected
                                        ? AppColor.coralRedGradientSelected
                                        : AppColor.whiteGradientIdle),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  // 1. Only close the drawer for mobile layout
                                  if (widget.isForMobile) {
                                    Navigator.of(context).pop();
                                  }

                                  // 2. Only trigger update if category is different
                                  if (state.selectedChannel?.categoryId !=
                                      data.categoryId) {
                                    final bloc = context.read<WiseBloc>();

                                    if (data.categoryId ==
                                        "favorites_category") {
                                      // Pre-set selection of Favourites
                                      bloc.add(
                                        SelectedChannelEvent(
                                          selectedChannel: data,
                                        ),
                                      );
                                    } else {
                                      bloc.add(
                                        VideosOnPerticulerChannelEvent(
                                          channelId: data.categoryId!,
                                          urlTillChannel: widget.urlTillChannel,
                                          isStopLoader: false,
                                        ),
                                      );
                                      bloc.add(
                                        SelectedChannelEvent(
                                          selectedChannel: data,
                                        ),
                                      );
                                    }
                                  }
                                },
                                child: Center(
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    horizontalTitleGap: 8,
                                    minLeadingWidth: 0,
                                    title: CText(
                                      data.categoryName ?? "N/A",
                                      maxLines: 2,
                                      color: (isSelected || isFocused)
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: (isSelected || isFocused)
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: (isSelected || isFocused)
                                            ? AppColor.whiteOpacity20
                                            : AppColor.whiteOpacity05,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        data.categoryId == "favorites_category"
                                            ? Icons.favorite_rounded
                                            : Icons.folder_open_rounded,
                                        color: (isSelected || isFocused)
                                            ? Colors.white
                                            : AppColor.coralRed,
                                        size: 26,
                                      ),
                                    ),
                                    trailing: (isSelected || isFocused)
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 18,
                                          )
                                        : Icon(
                                            Icons.arrow_forward_ios,
                                            size: 12,
                                            color: AppColor.whiteOpacity50,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
      },
    );
  }
}
