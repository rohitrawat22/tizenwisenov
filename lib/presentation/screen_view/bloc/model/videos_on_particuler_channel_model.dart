class VideosOnPerticulerChannelModel {
  int? num;
  String? name;
  String? streamType;
  int? streamId;
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
      streamId: 0,
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
    num = json['num'];
    name = json['name'];
    streamType = json['stream_type'];
    streamId = json['stream_id'];
    streamIcon = json['stream_icon'];
    epgChannelId = json['epg_channel_id'];
    added = json['added'];
    categoryId = json['category_id'];
    customSid = json['custom_sid'];
    tvArchive = json['tv_archive'];
    directSource = json['direct_source'];
    tvArchiveDuration = json['tv_archive_duration'];
    containerExtension = json['container_extension'] ?? json['containerExtension'];
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
