import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:wiseplayertizen/data/models/fav.mode.dart';

class HiveService {
  static const String favBoxName = 'favoritesBox';

  static Future<void> init() async {
    await Hive.initFlutter();
    // Register adapter if FavModel was generated via build_runner,
    // or just store JSON strings if we don't want to use TypeAdapters yet.
    // For simplicity and immediate migration without build_runner, we will store maps.
    await Hive.openBox(favBoxName);
  }

  static Box get _box => Hive.box(favBoxName);

  static Future<void> addFav(FavModel model) async {
    // Storing as JSON map to avoid needing a TypeAdapter generation right now
    await _box.put(model.id, model.toJson());
  }

  static List<FavModel> getFavList() {
    final List<FavModel> favorites = [];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value != null) {
        try {
          if (value is String) {
            favorites.add(FavModel.fromJson(jsonDecode(value)));
          } else {
            favorites.add(
              FavModel.fromJson(Map<String, dynamic>.from(value as Map)),
            );
          }
        } catch (e) {
          // Skip corrupted entries
        }
      }
    }
    return favorites;
  }

  static Future<void> deleteFav(String id) async {
    await _box.delete(id);
  }

  static Future<void> clearAll() async {
    await _box.clear();
  }
}
