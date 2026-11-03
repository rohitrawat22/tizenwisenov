// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'wise_bloc.dart';

enum Status { initial, loading, success, error, littleError }

class WiseState extends Equatable {
  List<ChannelModel> channelsList;
  ChannelModel? selectedChannel;
  VideosOnPerticulerChannelModel? selectedVideo;
  List<ChannelModel> filterChannelsList;
  List<GetplayListModel> playLists;
  List<VideosOnPerticulerChannelModel> videoOnParticulerChannelList;
  List<VideosOnPerticulerChannelModel> filterVideoOnParticulerChannelList;
  List<FavModel> favorites;
  bool isFavoritesLoading;

  // int channelIndex;
  Status status;
  String errorMessage;
  String videoUrl;
  String resumeSeconds;
  String streamIDMovie;
  bool isVideoLoaded;
  bool isCatchUpPlayback;
  bool isValidPlayList;
  bool isStopLoader;
  bool isMoreVideoOnParticulerChannelListLoading;
  String openPaypallUrl;
  PaymentInvoiceModel? paymentInvoiceSingleData;
  bool isSearchChannelOnTextField;
  String localeWord;

  WiseState({
    // this.paymentInvoiceSingleData=  PaymentInvoiceModel.empty(),
    this.channelsList = const [],
    this.selectedChannel,
    this.selectedVideo,
    this.streamIDMovie = "",
    this.resumeSeconds = "0",
    this.isMoreVideoOnParticulerChannelListLoading = false,
    this.filterChannelsList = const [],

    this.playLists = const [],
    this.videoOnParticulerChannelList = const [],
    this.filterVideoOnParticulerChannelList = const [],
    this.favorites = const [],
    this.isFavoritesLoading = false,
    // this.channelIndex = 0,
    this.status = Status.initial,
    this.errorMessage = "",
    this.videoUrl = "",
    this.isVideoLoaded = false,
    this.isCatchUpPlayback = false,
    this.isValidPlayList = false,
    this.isStopLoader = true,
    this.openPaypallUrl = "",
    this.paymentInvoiceSingleData,
    this.isSearchChannelOnTextField = true,
    this.localeWord = "",
  });

  WiseState copyWith({
    List<ChannelModel>? channelsList,
    ChannelModel? selectedChannel,
    VideosOnPerticulerChannelModel? selectedVideo,
    List<ChannelModel>? filterChannelsList,
    List<VideosOnPerticulerChannelModel>? videoOnParticulerChannelList,
    List<VideosOnPerticulerChannelModel>? filterVideoOnParticulerChannelList,
    List<GetplayListModel>? playLists,
    List<FavModel>? favorites,
    bool? isFavoritesLoading,
    int? channelIndex,
    Status? status,
    String? resumeSeconds,
    String? errorMessage,
    String? streamIDMovie,
    String? videoUrl,
    bool? isMoreVideoOnParticulerChannelListLoading,
    bool? isVideoLoaded,
    bool? isCatchUpPlayback,
    bool? isValidPlayList,
    bool? isStopLoader,
    String? openPaypallUrl,
    PaymentInvoiceModel? paymentInvoiceSingleData,
    String? localeWord,
  }) {
    return WiseState(
      channelsList: channelsList ?? this.channelsList,
      streamIDMovie: streamIDMovie ?? this.streamIDMovie,
      selectedChannel: selectedChannel ?? this.selectedChannel,
      filterChannelsList: filterChannelsList ?? this.filterChannelsList,
      videoOnParticulerChannelList:
          videoOnParticulerChannelList ?? this.videoOnParticulerChannelList,
      filterVideoOnParticulerChannelList:
          filterVideoOnParticulerChannelList ??
          this.filterVideoOnParticulerChannelList,
      // channelIndex: channelIndex ?? this.channelIndex,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      playLists: playLists ?? this.playLists,
      favorites: favorites ?? this.favorites,
      isFavoritesLoading: isFavoritesLoading ?? this.isFavoritesLoading,
      videoUrl: videoUrl ?? this.videoUrl,
      resumeSeconds: resumeSeconds ?? this.resumeSeconds,
      isMoreVideoOnParticulerChannelListLoading:
          isMoreVideoOnParticulerChannelListLoading ??
          this.isMoreVideoOnParticulerChannelListLoading,
      isVideoLoaded: isVideoLoaded ?? this.isVideoLoaded,
      isCatchUpPlayback: isCatchUpPlayback ?? this.isCatchUpPlayback,
      isValidPlayList: isValidPlayList ?? this.isValidPlayList,
      isStopLoader: isStopLoader ?? this.isStopLoader,
      openPaypallUrl: openPaypallUrl ?? this.openPaypallUrl,
      paymentInvoiceSingleData:
          paymentInvoiceSingleData ?? this.paymentInvoiceSingleData,
      selectedVideo: selectedVideo ?? this.selectedVideo,
      localeWord: localeWord ?? this.localeWord,
    );
  }

  @override
  List<Object?> get props => [
    selectedChannel,
    filterChannelsList,
    channelsList,
    videoOnParticulerChannelList,
    filterVideoOnParticulerChannelList,
    playLists,
    favorites,
    isFavoritesLoading,
    status,
    errorMessage,
    videoUrl,
    isVideoLoaded,
    streamIDMovie,
    isCatchUpPlayback,
    isValidPlayList,
    isStopLoader,
    openPaypallUrl,
    paymentInvoiceSingleData,
    selectedVideo,
    localeWord,
    isMoreVideoOnParticulerChannelListLoading,
  ];
}
