// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wiseplayertizen/core/const/global_data/global_data.dart';
import 'package:wiseplayertizen/core/shared_pref/shared_pref.dart';
import 'package:wiseplayertizen/data/models/fav.mode.dart';
import 'package:wiseplayertizen/presentation/screen_view/bloc/model/payment%20_invoice_model.dart';

import 'package:wiseplayertizen/presentation/screen_view/bloc/repo/api_repo.dart';
import 'package:wiseplayertizen/data/local_storage/pin_security_service.dart';

import 'model/channel_model.dart';
import 'model/get_playList_model.dart';
import 'model/videos_on_particuler_channel_model.dart';

part 'wise_event.dart';
part 'wise_state.dart';

class WiseBloc extends Bloc<WiseEvent, WiseState> {
  final PinSecurityService _pinService = PinSecurityService();
  ApiRepo apiRepo;
  final Connectivity _connectivity = Connectivity();

  WiseBloc(this.apiRepo) : super(WiseState()) {
    on<ChannelEvent>(_channelEvent);
    on<VideosOnPerticulerChannelEvent>(_videosOnPerticulerChannelEvent);
    on<GetPlayListEvent>(_getPlayListEvent);
    on<GetVideoUrlEvent>(_getVideoUrlEvent);
    on<SetDirectVideoUrlEvent>(_setDirectVideoUrlEvent);
    on<GetTimeshiftUrlEvent>(_getTimeshiftUrlEvent);

    on<ValidPlayListCheckEvent>(_validPlayListCheckEvent);
    on<DownloadInvoicePdfEvent>(_downloadInvoicePdfEvent);
    on<ValidPlayListResetFlagEvent>(_validPlayListResetFlagEvent);
    on<ResetVideoUrlEvent>(_resetVideoUrlEvent);
    on<PaymentEvent>(_paymentEvent);
    on<PaymentInvoiceEvent>(_paymentInvoiceEvent);
    on<FilterVideosOnPerticulerChannelEvent>(
      _filterVideosOnPerticulerChannelEvent,
    );
    on<SelectedChannelEvent>(_selectedChannelEvent);
    on<SelectedVideoEvent>(_selectedVideoEvent);
    on<ChangeLanguageEvent>(_changeLanguageEvent);
    on<PinPlaylistEvent>(_pinPlaylistEvent);
    on<UnpinPlaylistEvent>(_unpinPlaylistEvent);
    on<TogglePlaylistLockEvent>(_togglePlaylistLockEvent);
    on<SetDevicePinEvent>(_setDevicePinEvent);
    on<RemoveDevicePinEvent>(_removeDevicePinEvent);
    on<ChangePinEvent>(_changePinEvent);
  }

  _channelEvent(ChannelEvent event, Emitter<WiseState> emit) async {
    emit(
      state.copyWith(
        status: Status.loading,
        filterVideoOnParticulerChannelList: [],
      ),
    );
    try {
      List<ChannelModel> data = await apiRepo.getChannels(event.url);
      String channelId = '';
      ChannelModel selectedChannel;

      if (data.isNotEmpty) {
        final currentCategoryId = state.selectedChannel?.categoryId;
        if (state.selectedChannel != null &&
            currentCategoryId != null &&
            currentCategoryId.isNotEmpty) {
          selectedChannel = state.selectedChannel!;
          channelId = currentCategoryId;
        } else {
          channelId = data.first.categoryId ?? '';
          selectedChannel = data.first;
        }
        emit(
          state.copyWith(
            channelsList: data,
            selectedChannel: selectedChannel,
            status: Status.success,
            filterChannelsList: data,
          ),
        );
        if (state.status == Status.success && channelId.isNotEmpty) {
          add(
            VideosOnPerticulerChannelEvent(
              channelId: channelId,
              urlTillChannel: event.url,
            ),
          );
        }
      }
    } catch (e) {
      emit(state.copyWith(status: Status.error, errorMessage: e.toString()));
    }
  }

  _videosOnPerticulerChannelEvent(
    VideosOnPerticulerChannelEvent event,
    Emitter<WiseState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          isMoreVideoOnParticulerChannelListLoading: true,
          status: Status.loading,
        ),
      );
      List<VideosOnPerticulerChannelModel> data = await apiRepo
          .getVideoOnPerticulerChannels(
            channelId: event.channelId,
            urlTillChannel: event.urlTillChannel,
          );

      emit(
        state.copyWith(
          videoOnParticulerChannelList: data,
          filterVideoOnParticulerChannelList: data,
          status: Status.success,
          isStopLoader: true,
          isMoreVideoOnParticulerChannelListLoading: false,
        ),
      );
    } catch (e) {
      log('error in video on particular channel bloc is $e');
      emit(state.copyWith(status: Status.error, errorMessage: '$e'));
    }
  }

  _getPlayListEvent(GetPlayListEvent event, Emitter<WiseState> emit) async {
    emit(state.copyWith(status: Status.loading));
    log('get playlist event in bloc is running...');
    try {
      // Run both fetches concurrently
      final results = await Future.wait([
        apiRepo.getPlaylist(),
        apiRepo.getPinnedPlaylists().catchError((_) => <GetplayListModel>[]),
      ]);

      List<GetplayListModel> data = results[0] as List<GetplayListModel>;
      List<GetplayListModel> pinnedData = results[1] as List<GetplayListModel>;

      // Create a set of pinned IDs for fast lookup
      Set<String> pinnedIds = pinnedData.map((e) => e.id ?? '').toSet();

      // Set the flag and sort
      for (var playlist in data) {
        if (playlist.id != null && pinnedIds.contains(playlist.id)) {
          playlist.isPinned = true;
        }
      }

      data.sort((a, b) {
        if (a.isPinned == true && b.isPinned != true) return -1;
        if (a.isPinned != true && b.isPinned == true) return 1;
        return 0; // maintain original order otherwise
      });

      emit(state.copyWith(playLists: data, status: Status.success));
    } catch (e) {
      emit(state.copyWith(status: Status.error, errorMessage: e.toString()));
    }
  }

  _pinPlaylistEvent(PinPlaylistEvent event, Emitter<WiseState> emit) async {
    // Optimistic update: toggle flag immediately so the pin icon reacts instantly
    final updated = state.playLists.map((p) {
      if (p.id == event.playlistId) {
        final copy = GetplayListModel.fromJson(p.toJson());
        copy.isPinned = true;
        return copy;
      }
      return p;
    }).toList();
    updated.sort((a, b) {
      if (a.isPinned == true && b.isPinned != true) return -1;
      if (a.isPinned != true && b.isPinned == true) return 1;
      return 0;
    });
    emit(state.copyWith(playLists: updated));

    try {
      await apiRepo.pinPlaylist(event.playlistId);
    } catch (e) {
      // Revert on failure and show a non-blocking snackbar-level error
      emit(
        state.copyWith(status: Status.littleError, errorMessage: e.toString()),
      );
      add(GetPlayListEvent()); // Re-fetch to restore server truth
    }
  }

  _unpinPlaylistEvent(UnpinPlaylistEvent event, Emitter<WiseState> emit) async {
    // Optimistic update
    final updated = state.playLists.map((p) {
      if (p.id == event.playlistId) {
        final copy = GetplayListModel.fromJson(p.toJson());
        copy.isPinned = false;
        return copy;
      }
      return p;
    }).toList();
    updated.sort((a, b) {
      if (a.isPinned == true && b.isPinned != true) return -1;
      if (a.isPinned != true && b.isPinned == true) return 1;
      return 0;
    });
    emit(state.copyWith(playLists: updated));

    try {
      await apiRepo.unpinPlaylist(event.playlistId);
    } catch (e) {
      emit(
        state.copyWith(status: Status.littleError, errorMessage: e.toString()),
      );
      add(GetPlayListEvent());
    }
  }

  _togglePlaylistLockEvent(
    TogglePlaylistLockEvent event,
    Emitter<WiseState> emit,
  ) async {
    final updated = state.playLists.map((p) {
      if (p.id == event.playlistId) {
        final copy = GetplayListModel.fromJson(p.toJson());
        copy.isLocked = event.isLocked;
        return copy;
      }
      return p;
    }).toList();
    emit(state.copyWith(playLists: updated));

    try {
      await apiRepo.togglePlaylistLock(event.playlistId, event.isLocked);
    } catch (e) {
      emit(
        state.copyWith(status: Status.littleError, errorMessage: e.toString()),
      );
      add(GetPlayListEvent());
    }
  }

  /// Sets the device PIN on the server.
  _setDevicePinEvent(SetDevicePinEvent event, Emitter<WiseState> emit) async {
    try {
      await apiRepo.setDevicePin(newPin: event.pin, confirmPin: event.pin);
      await _pinService.setPin(event.pin); // keep local cache synced
      emit(state.copyWith(status: Status.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: Status.littleError,
          errorMessage:
              'Failed to set PIN: ${e.toString().replaceAll("ServerException: ", "")}',
        ),
      );
    }
  }

  /// Removes the device PIN from the server.
  _removeDevicePinEvent(
    RemoveDevicePinEvent event,
    Emitter<WiseState> emit,
  ) async {
    try {
      await apiRepo.removeDevicePin(event.currentPin);
      await _pinService.removePin(); // clear local cache on success
      emit(state.copyWith(status: Status.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: Status.littleError,
          errorMessage:
              'Failed to remove PIN: ${e.toString().replaceAll("ServerException: ", "")}',
        ),
      );
    }
  }

  /// Changes the device PIN on the server.
  _changePinEvent(ChangePinEvent event, Emitter<WiseState> emit) async {
    try {
      await apiRepo.setDevicePin(
        newPin: event.newPin,
        confirmPin: event.newPin,
        oldPin: event.oldPin,
      );
      await _pinService.setPin(event.newPin); // keep local cache synced
      emit(state.copyWith(status: Status.success));
    } catch (e) {
      emit(
        state.copyWith(
          status: Status.littleError,
          errorMessage:
              'Failed to change PIN: ${e.toString().replaceAll("ServerException: ", "")}',
        ),
      );
    }
  }

  _getVideoUrlEvent(GetVideoUrlEvent event, Emitter<WiseState> emit) async {
    emit(state.copyWith(status: Status.loading));
    try {
      final (url, resumeSeconds) = await apiRepo.getVideoUrl(
        urlTillPlayList: event.urlTillChannel,
        channelId: event.channelId,
        streamId: event.streamId,
        extension: event.extension,
      );
      log('the video url in bloc is $url');
      emit(
        state.copyWith(
          videoUrl: url,
          resumeSeconds: resumeSeconds?.toString() ?? "0",
          streamIDMovie: event.streamId.toString(),
          status: Status.success,
          isVideoLoaded: true,
          isCatchUpPlayback: false,
          isStopLoader: false,
        ),
      );
    } catch (e) {
      log('error in get video url bloc is $e');
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: e.toString(),
          isVideoLoaded: false,
        ),
      );
    }
  }

  /// HotPlayer-speed optimisation C: immediately emits a pre-built live URL
  /// into state. We show a brief loading state first so the loader remains
  /// visible until the player opens (prevents the frozen-screen flash).
  _setDirectVideoUrlEvent(
    SetDirectVideoUrlEvent event,
    Emitter<WiseState> emit,
  ) {
    log('🚀 [DirectURL] Opening stream instantly: ${event.videoUrl}');
    // Emit loading so the loader appears immediately on tap.
    emit(state.copyWith(status: Status.loading));
    // Then immediately resolve to success — the loader will be stopped
    // by the BlocConsumer listener once the player initialises.
    emit(
      state.copyWith(
        videoUrl: event.videoUrl,
        status: Status.success,
        isVideoLoaded: true,
        isCatchUpPlayback: false,
        isStopLoader: false,
        selectedVideo: event.selectedVideo,
      ),
    );
  }

  _getTimeshiftUrlEvent(
    GetTimeshiftUrlEvent event,
    Emitter<WiseState> emit,
  ) async {
    emit(state.copyWith(status: Status.loading));
    try {
      String url = await apiRepo.getTimeshiftUrl(
        urlTillPlayList: event.urlTillChannel,
        streamId: event.streamId,
        timestamp: event.timestamp,
        duration: event.duration,
        extension: event.extension,
      );
      log('the timeshift url in bloc is $url');
      emit(
        state.copyWith(
          videoUrl: url,
          status: Status.success,
          isVideoLoaded: true,
          isCatchUpPlayback: true,
          isStopLoader: false,
        ),
      );
    } catch (e) {
      log('error in get timeshift url bloc is $e');
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: e.toString(),
          isVideoLoaded: false,
        ),
      );
    }
  }

  _validPlayListCheckEvent(
    ValidPlayListCheckEvent event,
    Emitter<WiseState> emit,
  ) async {
    emit(state.copyWith(status: Status.loading));
    try {
      bool isValid = await apiRepo.isValidPlayList(
        playListId: event.playListId,
      );
      emit(state.copyWith(isValidPlayList: isValid, status: Status.success));
    } catch (e) {
      emit(
        state.copyWith(
          isValidPlayList: false,
          status: Status.littleError,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  _validPlayListResetFlagEvent(
    ValidPlayListResetFlagEvent event,
    Emitter<WiseState> emit,
  ) async {
    // Do NOT emit loading here — it causes a full-screen LoaderScreen flash
    // every time the playlist selection changes. Emit success directly.
    emit(state.copyWith(isValidPlayList: false, status: Status.success));
  }

  _resetVideoUrlEvent(ResetVideoUrlEvent event, Emitter<WiseState> emit) async {
    await Future.delayed(const Duration(seconds: 2), () async {
      emit(
        state.copyWith(
          videoUrl: '',
          isVideoLoaded: false,
          isCatchUpPlayback: false,
          selectedVideo: VideosOnPerticulerChannelModel.empty(),
          status: Status.success,
        ),
      );
    });
  }

  _paymentEvent(PaymentEvent event, Emitter<WiseState> emit) async {
    emit(state.copyWith(status: Status.loading));
    try {
      print("dfsdfsdf${event.isLifeTimePayment.toString()}");

      Map<String, dynamic> data = await apiRepo.openPaypall(
        isLimeTimePayment: event.isLifeTimePayment,
        endpoints: '/api/payment/checkout',
      );
      emit(
        state.copyWith(
          openPaypallUrl: data['checkoutUrl'],
          status: Status.success,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString(), status: Status.error));
    }
  }

  _paymentInvoiceEvent(
    PaymentInvoiceEvent event,
    Emitter<WiseState> emit,
  ) async {
    emit(state.copyWith(status: Status.loading));
    try {
      if (kDebugMode) log('Fetching payment invoice for deviceId: $deviceId');

      PaymentInvoiceModel data = await apiRepo.getPlanInvoice(
        endpoints: '/api/payment/invoice/current?deviceId=$deviceId',
      );
      emit(
        state.copyWith(paymentInvoiceSingleData: data, status: Status.success),
      );
      log(
        'your invoice data is returning state --> ${state.paymentInvoiceSingleData?.toJson()}',
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString(), status: Status.error));
      log('paymentInvoiceEvent error: ${e.toString()}');
    }
  }

  _filterVideosOnPerticulerChannelEvent(
    FilterVideosOnPerticulerChannelEvent event,
    Emitter<WiseState> emit,
  ) async {
    final query = event.searchText.trim().toLowerCase();
    if (query.isEmpty) {
      if (event.isSearchChannelOnTextField) {
        emit(
          state.copyWith(
            filterChannelsList: state.channelsList,
            status: Status.success,
            isStopLoader: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            filterVideoOnParticulerChannelList:
                state.videoOnParticulerChannelList,
            status: Status.success,
            isStopLoader: false,
          ),
        );
      }
      return;
    }

    if (event.isSearchChannelOnTextField) {
      // PERF: offload .where().toList() to a background isolate via compute()
      // so large channel lists (1000+ items) don't jank the UI on every keypress.
      final List<ChannelModel> filteredList = await compute(
        _filterChannels,
        _ChannelFilterArgs(list: state.channelsList, query: query),
      );
      emit(
        state.copyWith(
          filterChannelsList: filteredList,
          status: Status.success,
          isStopLoader: false,
        ),
      );
    } else {
      // PERF: same isolate offload for video lists.
      final List<VideosOnPerticulerChannelModel> filteredList = await compute(
        _filterVideos,
        _VideoFilterArgs(
          list: state.videoOnParticulerChannelList,
          query: query,
        ),
      );
      emit(
        state.copyWith(
          filterVideoOnParticulerChannelList: filteredList,
          status: Status.success,
          isStopLoader: false,
        ),
      );
    }
  }

  _downloadInvoicePdfEvent(
    DownloadInvoicePdfEvent event,
    Emitter<WiseState> emit,
  ) async {
    emit(state.copyWith(status: Status.loading));
    try {
      await apiRepo.downloadInvoicePdf(
        invoiceId: event.invoiceId,
        deviceId: deviceId ?? '',
      );
      emit(state.copyWith(status: Status.success));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString(), status: Status.error));
    }
  }

  _selectedChannelEvent(SelectedChannelEvent event, Emitter<WiseState> emit) {
    emit(
      state.copyWith(
        selectedChannel: event.selectedChannel,
        status: Status.success,
        isStopLoader: false,
      ),
    );
  }

  _selectedVideoEvent(SelectedVideoEvent event, Emitter<WiseState> emit) async {
    // Do NOT change status here — if a GetVideoUrlEvent is already in flight
    // (status == Status.loading), overwriting it with Status.initial would
    // cause the loader to disappear before the URL arrives.
    emit(
      state.copyWith(
        selectedVideo: event.selectedVideo,
        // Preserve the current status so an in-progress load stays as loading.
        status: state.status,
        isStopLoader: false,
      ),
    );
  }

  _changeLanguageEvent(
    ChangeLanguageEvent event,
    Emitter<WiseState> emit,
  ) async {
    String localeWord = await SharedPref.getLanguage();
    if (event.localWord.isNotEmpty) {
      SharedPref.setLanguage(languageWord: event.localWord);
      emit(state.copyWith(localeWord: event.localWord, status: Status.success));
    } else {
      emit(state.copyWith(localeWord: localeWord, status: Status.success));
    }
  }
}

// ─── Isolate-safe filter helpers ─────────────────────────────────────────────
// These must be top-level (not closures) so compute() can send them to a
// background isolate. Each takes a single argument object.

class _ChannelFilterArgs {
  final List<ChannelModel> list;
  final String query;
  const _ChannelFilterArgs({required this.list, required this.query});
}

List<ChannelModel> _filterChannels(_ChannelFilterArgs args) {
  return args.list.where((c) {
    final name = c.categoryName?.toLowerCase();
    final id = c.categoryId?.toLowerCase();
    return (name != null && name.contains(args.query)) ||
        (id != null && id.contains(args.query));
  }).toList();
}

class _VideoFilterArgs {
  final List<VideosOnPerticulerChannelModel> list;
  final String query;
  const _VideoFilterArgs({required this.list, required this.query});
}

List<VideosOnPerticulerChannelModel> _filterVideos(_VideoFilterArgs args) {
  return args.list.where((video) {
    final name = video.name?.toLowerCase();
    final streamIdStr = video.streamId?.toString();
    return (name != null && name.contains(args.query)) ||
        (streamIdStr != null && streamIdStr.contains(args.query));
  }).toList();
}
