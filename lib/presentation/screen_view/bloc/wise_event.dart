part of 'wise_bloc.dart';

@immutable
sealed class WiseEvent {}

// class SelectChannelIndexEvent extends WiseEvent {
//   final int selectedChannelIndex;
//   final bool isStopLoader;
//   SelectChannelIndexEvent({
//     required this.selectedChannelIndex,
//     this.isStopLoader = true,
//   });
// }

class StreamInterNetConnectivityEvent extends WiseEvent {}

class GetPlayListEvent extends WiseEvent {
  // final String playListId;
  GetPlayListEvent();
}

class PinPlaylistEvent extends WiseEvent {
  final String playlistId;
  PinPlaylistEvent({required this.playlistId});
}

class UnpinPlaylistEvent extends WiseEvent {
  final String playlistId;
  UnpinPlaylistEvent({required this.playlistId});
}

class TogglePlaylistLockEvent extends WiseEvent {
  final String playlistId;
  final bool isLocked;
  final String? pin;
  TogglePlaylistLockEvent({required this.playlistId, required this.isLocked, this.pin});
}

class SetDevicePinEvent extends WiseEvent {
  final String pin;
  SetDevicePinEvent({required this.pin});
}

class RemoveDevicePinEvent extends WiseEvent {
  final String currentPin;
  RemoveDevicePinEvent({required this.currentPin});
}

class ChangePinEvent extends WiseEvent {
  final String oldPin;
  final String newPin;
  ChangePinEvent({required this.oldPin, required this.newPin});
}
class ChannelEvent extends WiseEvent {
  final String url;
  ChannelEvent({required this.url});
}

class VideosOnPerticulerChannelEvent extends WiseEvent {
  // final List<VideosOnPerticulerChannelModel> videoOnParticulerChannel;
  final String channelId;
  final String urlTillChannel;
  final bool isStopLoader;
  VideosOnPerticulerChannelEvent({
    required this.channelId,
    required this.urlTillChannel,
    this.isStopLoader = true,
  });
}

class GetVideoUrlEvent extends WiseEvent {
  // final List<VideosOnPerticulerChannelModel> videoOnParticulerChannel;
  final String channelId;
  final String urlTillChannel;
  final String streamId;
  final String? extension;
  GetVideoUrlEvent({
    required this.channelId,
    required this.urlTillChannel,
    required this.streamId,
    this.extension,
  });
}

/// HotPlayer-speed optimisation C: fires when the client can construct the
/// live stream URL directly (no API round-trip needed).
/// Format: {serverUrl}/live/{username}/{password}/{streamId}.m3u8
class SetDirectVideoUrlEvent extends WiseEvent {
  final String videoUrl;
  final VideosOnPerticulerChannelModel? selectedVideo;
  SetDirectVideoUrlEvent({required this.videoUrl, this.selectedVideo});
}

class GetTimeshiftUrlEvent extends WiseEvent {
  final String urlTillChannel;
  final String streamId;
  final String timestamp;
  final int duration;
  final String extension;
  GetTimeshiftUrlEvent({
    required this.urlTillChannel,
    required this.streamId,
    required this.timestamp,
    this.duration = 60,
    this.extension = 'ts',
  });
}

// class ResetVideoFlagEvent extends WiseEvent {}

class ValidPlayListCheckEvent extends WiseEvent {
  final String playListId;
  ValidPlayListCheckEvent({required this.playListId});
}

class ValidPlayListResetFlagEvent extends WiseEvent {
  ValidPlayListResetFlagEvent();
}

class ResetVideoUrlEvent extends WiseEvent {
  ResetVideoUrlEvent();
}

class PaymentEvent extends WiseEvent {
  final String isLifeTimePayment;
  PaymentEvent({required this.isLifeTimePayment});
}

class PaymentInvoiceEvent extends WiseEvent {}

class DownloadInvoicePdfEvent extends WiseEvent {
  final String invoiceId;
  DownloadInvoicePdfEvent({required this.invoiceId});
}

class FilterVideosOnPerticulerChannelEvent extends WiseEvent {
  final String searchText;
  final bool isSearchChannelOnTextField;

  FilterVideosOnPerticulerChannelEvent({
    required this.searchText,
    required this.isSearchChannelOnTextField,
  });
}

class SelectedChannelEvent extends WiseEvent {
  final ChannelModel selectedChannel;
  SelectedChannelEvent({required this.selectedChannel});
}

class SelectedVideoEvent extends WiseEvent {
  final VideosOnPerticulerChannelModel selectedVideo;
  SelectedVideoEvent({required this.selectedVideo});
}

class ChangeLanguageEvent extends WiseEvent {
  final String localWord;
  ChangeLanguageEvent({required this.localWord});
}
