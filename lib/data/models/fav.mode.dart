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
  });

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
      'FavModel(id: $id, title: $title, isLive: $isLive, categoryId: $categoryId)';
}
