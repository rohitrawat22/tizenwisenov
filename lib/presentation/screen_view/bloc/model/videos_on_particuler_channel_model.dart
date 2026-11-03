class VideosOnPerticulerChannelModel {
  int? num;
  String? name;
  String? streamType;
  String? streamId;
  String? streamIcon;
  String? epgChannelId;
  String? added;
  String? categoryId;
  String? customSid;
  int? tvArchive;
  String? directSource;
  int? tvArchiveDuration;
  String? containerExtension;

  VideosOnPerticulerChannelModel({
    this.num,
    this.name,
    this.streamType,
    this.streamId,
    this.streamIcon,
    this.epgChannelId,
    this.added,
    this.categoryId,
    this.customSid,
    this.tvArchive,
    this.directSource,
    this.tvArchiveDuration,
    this.containerExtension,
  });
  factory VideosOnPerticulerChannelModel.empty() {
    return VideosOnPerticulerChannelModel(
      num: 0,
      name: '',
      streamType: '',
      streamId: "0",
      streamIcon: '',
      epgChannelId: '',
      added: '',
      categoryId: '',
      customSid: '',
      tvArchive: 0,
      directSource: '',
      tvArchiveDuration: 0,
      containerExtension: '',
    );
  }

  VideosOnPerticulerChannelModel.fromJson(Map<String, dynamic> json) {
    num = json['num'] is int
        ? json['num']
        : int.tryParse(json['num']?.toString() ?? '');
    name = json['name']?.toString();
    streamType = json['stream_type']?.toString();
    streamId = json['stream_id'].toString();
    streamIcon = json['stream_icon']?.toString();
    epgChannelId = json['epg_channel_id']?.toString();
    added = json['added']?.toString();
    categoryId = json['category_id']?.toString();
    customSid = json['custom_sid']?.toString();
    tvArchive = json['tv_archive'] is int
        ? json['tv_archive']
        : int.tryParse(json['tv_archive']?.toString() ?? '');
    directSource = json['direct_source']?.toString();
    tvArchiveDuration = json['tv_archive_duration'] is int
        ? json['tv_archive_duration']
        : int.tryParse(json['tv_archive_duration']?.toString() ?? '');
    containerExtension =
        (json['container_extension'] ?? json['containerExtension'])?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['num'] = num;
    data['name'] = name;
    data['stream_type'] = streamType;
    data['stream_id'] = streamId;
    data['stream_icon'] = streamIcon;
    data['epg_channel_id'] = epgChannelId;
    data['added'] = added;
    data['category_id'] = categoryId;
    data['custom_sid'] = customSid;
    data['tv_archive'] = tvArchive;
    data['direct_source'] = directSource;
    data['tv_archive_duration'] = tvArchiveDuration;
    data['container_extension'] = containerExtension;
    return data;
  }

  bool get isCatchUpEnabled => tvArchive == 1;

  int get catchUpDurationMinutes {
    final days = tvArchiveDuration ?? 0;
    return days > 0 ? days * 24 * 60 : 0;
  }
}
