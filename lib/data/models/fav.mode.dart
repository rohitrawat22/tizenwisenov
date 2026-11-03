import 'dart:convert';

class FavModel {
  final String id;
  final String url;
  final String photoImage;
  final String title;
  final String? categoryId;
  final String? urlTillChannel;
  final bool isLive;
  final String? containerExtension;
  final String? type; // 'live', 'movie', 'series'
  final String? playlistId;
  final String? addedAt; // ISO timestamp from server

  FavModel({
    required this.id,
    required this.url,
    required this.photoImage,
    required this.title,
    this.categoryId,
    this.urlTillChannel,
    this.isLive = false,
    this.containerExtension,
    this.type,
    this.playlistId,
    this.addedAt,
  });

  /// Returns the stream type enum string the API expects: "LIVE", "VOD", or "SERIES".
  String get streamType {
    if (type != null) {
      switch (type!.toLowerCase()) {
        case 'live':
          return 'LIVE';
        case 'series':
          return 'SERIES';
        default:
          return 'VOD';
      }
    }
    return isLive ? 'LIVE' : 'VOD';
  }

  /// Build from the server API response (`GET /api/favorites/{playlistId}`).
  factory FavModel.fromApiJson(Map<String, dynamic> json) {
    final String rawStreamType = (json['streamType'] ?? 'VOD')
        .toString()
        .toUpperCase();
    final bool live = rawStreamType == 'LIVE';
    final String typeValue;
    switch (rawStreamType) {
      case 'LIVE':
        typeValue = 'live';
        break;
      case 'SERIES':
        typeValue = 'series';
        break;
      default:
        typeValue = 'movie';
    }
    return FavModel(
      id: (json['streamId'] ?? json['id'] ?? '').toString(),
      url: '',
      photoImage: json['streamIcon'] ?? '',
      title: json['name'] ?? '',
      categoryId: json['categoryId']?.toString(),
      urlTillChannel: json['urlTillChannel'],
      isLive: live,
      containerExtension: json['containerExtension'],
      type: typeValue,
      playlistId: json['playlistId']?.toString(),
      addedAt: json['addedAt']?.toString(),
    );
  }

  /// Build from legacy local Hive/JSON data.
  factory FavModel.fromJson(Map<String, dynamic> json) {
    return FavModel(
      id: json['id'] ?? "",
      url: json['url'] ?? "",
      photoImage: json['photoImage'] ?? "",
      title: json['title'] ?? "",
      categoryId: json['categoryId'],
      urlTillChannel: json['urlTillChannel'],
      isLive: json['isLive'] ?? false,
      containerExtension: json['containerExtension'],
      type: json['type'],
      playlistId: json['playlistId'],
      addedAt: json['addedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'photoImage': photoImage,
      'title': title,
      'categoryId': categoryId,
      'urlTillChannel': urlTillChannel,
      'isLive': isLive,
      'containerExtension': containerExtension,
      'type': type ?? (isLive ? 'live' : 'movie'), // fallback for old data
      'playlistId': playlistId,
      'addedAt': addedAt,
    };
  }

  String toMapString() => jsonEncode(toJson());

  // ✅ copyWith — kisi ek field update karne ke liye
  FavModel copyWith({
    String? id,
    String? url,
    String? photoImage,
    String? title,
    String? categoryId,
    String? urlTillChannel,
    bool? isLive,
    String? containerExtension,
    String? playlistId,
  }) {
    return FavModel(
      id: id ?? this.id,
      url: url ?? this.url,
      photoImage: photoImage ?? this.photoImage,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      urlTillChannel: urlTillChannel ?? this.urlTillChannel,
      isLive: isLive ?? this.isLive,
      containerExtension: containerExtension ?? this.containerExtension,
      playlistId: playlistId ?? this.playlistId,
    );
  }

  // ✅ == operator — contains() aur removeWhere() sahi kaam kare
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FavModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FavModel(id: $id, title: $title, isLive: $isLive, categoryId: $categoryId, playlistId: $playlistId)';
}
