// lib/core/utils/json_parse.dart

String? asString(dynamic v) => v?.toString();

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

List<String> asStringList(dynamic v) {
  if (v is List) {
    return v
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return const [];
}
// lib/presentation/screen_view/bloc/model/series_list_model.dart

/// Response of: {{baseUrl}}/api/series?playlistId={{playlistId}}&categoryId={{categoryId}}
class SeriesListModel {
  final int? num;
  final String? name;
  final int? streamId;
  final String? streamIcon;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? lastModified;
  final String? rating;
  final String? categoryId;
  final List<String> backdropPath;
  final String? youtubeTrailer;
  final String? tmdb;
  final String? episodeRunTime;
  final List<int> categoryIds;
  final String? rating5based;

  const SeriesListModel({
    this.num,
    this.name,
    this.streamId,
    this.streamIcon,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.lastModified,
    this.rating,
    this.categoryId,
    this.backdropPath = const [],
    this.youtubeTrailer,
    this.tmdb,
    this.episodeRunTime,
    this.categoryIds = const [],
    this.rating5based,
  });

  factory SeriesListModel.fromJson(Map<String, dynamic> json) {
    return SeriesListModel(
      num: asInt(json['num']),
      name: asString(json['name']),
      streamId: asInt(json['stream_id']),
      streamIcon: asString(json['stream_icon']),
      plot: asString(json['plot']),
      cast: asString(json['cast']),
      director: asString(json['director']),
      genre: asString(json['genre']),
      releaseDate: asString(json['releaseDate']),
      lastModified: asString(json['last_modified']),
      rating: asString(json['rating']),
      categoryId: asString(json['category_id']),
      backdropPath: asStringList(json['backdrop_path']),
      youtubeTrailer: asString(json['youtube_trailer']),
      tmdb: asString(json['tmdb']),
      episodeRunTime: asString(json['episode_run_time']),
      categoryIds: (json['category_ids'] is List)
          ? (json['category_ids'] as List).map((e) => asInt(e) ?? 0).toList()
          : const [],
      rating5based: asString(json['rating_5based']),
    );
  }

  static List<SeriesListModel> listFromJson(List<dynamic> jsonList) {
    return jsonList
        .whereType<Map<String, dynamic>>()
        .map((e) => SeriesListModel.fromJson(e))
        .toList();
  }

  /// Safe display helpers — never show "null" in the UI
  String get displayName => name ?? 'Untitled';
  String get displayGenre =>
      (genre != null && genre!.trim().isNotEmpty) ? genre! : '—';
  double get ratingValue => double.tryParse(rating5based ?? '') ?? 0;
}
// lib/presentation/screen_view/bloc/model/series_detail_model.dart

/// Response of: {{baseUrl}}/api/series?playlistId={{playlistId}}&seriesId={{seriesId}}
class SeriesDetailModel {
  final SeriesInfo info;
  final List<SeriesSeason> seasons;
  final Map<String, List<SeriesEpisode>> episodes;

  const SeriesDetailModel({
    required this.info,
    this.seasons = const [],
    this.episodes = const {},
  });

  factory SeriesDetailModel.fromJson(Map<String, dynamic> json) {
    final episodesRaw = json['episodes'];
    final Map<String, List<SeriesEpisode>> episodesMap = {};

    if (episodesRaw is Map) {
      episodesRaw.forEach((key, value) {
        if (value is List) {
          episodesMap[key.toString()] =
              value
                  .whereType<Map<String, dynamic>>()
                  .map((e) => SeriesEpisode.fromJson(e))
                  .toList()
                ..sort(
                  (a, b) => (a.episodeNum ?? 0).compareTo(b.episodeNum ?? 0),
                );
        } else if (value is Map) {
          episodesMap[key.toString()] =
              value.values
                  .whereType<Map<String, dynamic>>()
                  .map((e) => SeriesEpisode.fromJson(e))
                  .toList()
                ..sort(
                  (a, b) => (a.episodeNum ?? 0).compareTo(b.episodeNum ?? 0),
                );
        }
      });
    } else if (episodesRaw is List) {
      episodesMap['1'] =
          episodesRaw
              .whereType<Map<String, dynamic>>()
              .map((e) => SeriesEpisode.fromJson(e))
              .toList()
            ..sort((a, b) => (a.episodeNum ?? 0).compareTo(b.episodeNum ?? 0));
    }

    // Parse seasons (safely supporting both JSON List and JSON Map from Xtream API)
    List<SeriesSeason> seasonsList = [];
    final seasonsRaw = json['seasons'];
    if (seasonsRaw is List) {
      seasonsList = seasonsRaw
          .whereType<Map<String, dynamic>>()
          .map((e) => SeriesSeason.fromJson(e))
          .toList();
    } else if (seasonsRaw is Map) {
      seasonsList = seasonsRaw.values
          .whereType<Map<String, dynamic>>()
          .map((e) => SeriesSeason.fromJson(e))
          .toList();
    }

    // FIX: If seasons is 0/empty but episodes has values, auto-generate seasons from episodes
    if (seasonsList.isEmpty && episodesMap.isNotEmpty) {
      final List<SeriesSeason> generatedSeasons = [];
      final sortedKeys = episodesMap.keys.toList()
        ..sort((a, b) {
          final intA = int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 0;
          final intB = int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 0;
          if (intA != intB) return intA.compareTo(intB);
          return a.compareTo(b);
        });

      for (int i = 0; i < sortedKeys.length; i++) {
        final key = sortedKeys[i];
        final eps = episodesMap[key] ?? [];
        final parsedNum = int.tryParse(key.replaceAll(RegExp(r'\D'), ''));

        int seasonNum;
        if (parsedNum != null && parsedNum > 0) {
          seasonNum = parsedNum;
        } else {
          final epWithSeason = eps.firstWhere(
            (e) => e.season != null && e.season! > 0,
            orElse: () => const SeriesEpisode(),
          );
          seasonNum = epWithSeason.season ?? (i + 1);
        }

        final firstCover = eps.isNotEmpty
            ? (eps.first.info.movieImage ?? eps.first.directSource)
            : null;

        generatedSeasons.add(
          SeriesSeason(
            name: 'Season $seasonNum',
            seasonNumber: seasonNum,
            episodeCount: eps.length,
            cover: firstCover,
          ),
        );
      }

      seasonsList = generatedSeasons;
    } else if (seasonsList.isNotEmpty && episodesMap.isNotEmpty) {
      // Ensure episodeCount is populated accurately for each season
      for (int i = 0; i < seasonsList.length; i++) {
        final s = seasonsList[i];
        final sNum = s.seasonNumber ?? (i + 1);
        final matchingEps =
            episodesMap[sNum.toString()] ??
            episodesMap[s.name?.replaceAll(RegExp(r'\D'), '') ?? ''] ??
            (i < episodesMap.length
                ? episodesMap[episodesMap.keys.elementAt(i)]
                : null);

        if ((s.episodeCount == null || s.episodeCount == 0) &&
            matchingEps != null &&
            matchingEps.isNotEmpty) {
          seasonsList[i] = SeriesSeason(
            name: s.name,
            episodeCount: matchingEps.length,
            overview: s.overview,
            airDate: s.airDate,
            cover: s.cover,
            coverTmdb: s.coverTmdb,
            seasonNumber: sNum,
            coverBig: s.coverBig,
            duration: s.duration,
          );
        }
      }
    }

    return SeriesDetailModel(
      info: SeriesInfo.fromJson(
        (json['info'] is Map<String, dynamic>) ? json['info'] : const {},
      ),
      seasons: seasonsList,
      episodes: episodesMap,
    );
  }

  /// Episodes for a given season number, safe against missing keys.
  List<SeriesEpisode> episodesForSeason(int seasonNumber) {
    if (episodes.containsKey(seasonNumber.toString())) {
      return episodes[seasonNumber.toString()]!;
    }
    for (final entry in episodes.entries) {
      final keyDigits = entry.key.replaceAll(RegExp(r'\D'), '');
      if (keyDigits.isNotEmpty && int.tryParse(keyDigits) == seasonNumber) {
        return entry.value;
      }
    }
    // Also check if any episode in the lists has season == seasonNumber
    for (final entry in episodes.entries) {
      final matching = entry.value
          .where((e) => e.season == seasonNumber)
          .toList();
      if (matching.isNotEmpty) {
        return matching;
      }
    }
    return const [];
  }

  /// Returns all available episodes across all seasons/keys, sorted by episode number.
  List<SeriesEpisode> get allEpisodes {
    final list = episodes.values.expand((e) => e).toList();
    list.sort((a, b) {
      final sA = a.season ?? 0;
      final sB = b.season ?? 0;
      if (sA != sB) return sA.compareTo(sB);
      return (a.episodeNum ?? 0).compareTo(b.episodeNum ?? 0);
    });
    return list;
  }

  int get totalSeasons => seasons.isNotEmpty
      ? seasons.length
      : (episodes.isNotEmpty ? episodes.keys.length : 0);

  int get totalEpisodes =>
      episodes.values.fold(0, (sum, list) => sum + list.length);
}

class SeriesInfo {
  final String? name;
  final String? cover;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? rating;
  final String? rating5based;
  final List<String> backdropPath;
  final String? youtubeTrailer;
  final String? episodeRunTime;
  final String? categoryId;

  const SeriesInfo({
    this.name,
    this.cover,
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.rating5based,
    this.backdropPath = const [],
    this.youtubeTrailer,
    this.episodeRunTime,
    this.categoryId,
  });

  factory SeriesInfo.fromJson(Map<String, dynamic> json) {
    return SeriesInfo(
      name: asString(json['name']),
      cover: asString(json['cover']),
      plot: asString(json['plot']),
      cast: asString(json['cast']),
      director: asString(json['director']),
      genre: asString(json['genre']),
      releaseDate: asString(json['releaseDate']),
      rating: asString(json['rating']),
      rating5based: asString(json['rating_5based']),
      backdropPath: asStringList(json['backdrop_path']),
      youtubeTrailer: asString(json['youtube_trailer']),
      episodeRunTime: asString(json['episode_run_time']),
      categoryId: asString(json['category_id']),
    );
  }

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : 'Untitled';
  String get displayPlot => (plot != null && plot!.trim().isNotEmpty)
      ? plot!
      : 'No description available.';
  String get displayCast =>
      (cast != null && cast!.trim().isNotEmpty) ? cast! : '—';
  String get displayDirector =>
      (director != null && director!.trim().isNotEmpty) ? director! : '—';
  String get displayGenre =>
      (genre != null && genre!.trim().isNotEmpty) ? genre! : '—';
  String get releaseYear => (releaseDate != null && releaseDate!.length >= 4)
      ? releaseDate!.substring(0, 4)
      : '—';
}

class SeriesSeason {
  final String? name;
  final int? episodeCount;
  final String? overview;
  final String? airDate;
  final String? cover;
  final String? coverTmdb;
  final int? seasonNumber;
  final String? coverBig;
  final String? duration;

  const SeriesSeason({
    this.name,
    this.episodeCount,
    this.overview,
    this.airDate,
    this.cover,
    this.coverTmdb,
    this.seasonNumber,
    this.coverBig,
    this.duration,
  });

  factory SeriesSeason.fromJson(Map<String, dynamic> json) {
    return SeriesSeason(
      name: asString(json['name']),
      episodeCount: asInt(json['episode_count']),
      overview: asString(json['overview']),
      airDate: asString(json['air_date']),
      cover: asString(json['cover']),
      coverTmdb: asString(json['cover_tmdb']),
      seasonNumber: asInt(json['season_number']),
      coverBig: asString(json['cover_big']),
      duration: asString(json['duration']),
    );
  }

  String get displayName => (name != null && name!.trim().isNotEmpty)
      ? name!
      : 'Season ${seasonNumber ?? '-'}';

  /// Prefer TMDB cover (always reachable) over the CDN cover, since CDN
  /// covers can 404 depending on server config; falls back gracefully.
  String? get displayCover => coverTmdb ?? cover ?? coverBig;
}

class SeriesEpisode {
  final String? id;
  final int? episodeNum;
  final String? title;
  final String? containerExtension;
  final EpisodeInfo info;
  final String? added;
  final int? season;
  final String? directSource;
  final WatchProgressModel? watchProgress;

  const SeriesEpisode({
    this.id,
    this.episodeNum,
    this.title,
    this.containerExtension,
    this.info = const EpisodeInfo(),
    this.added,
    this.season,
    this.directSource,
    this.watchProgress,
  });

  factory SeriesEpisode.fromJson(Map<String, dynamic> json) {
    return SeriesEpisode(
      id: asString(json['id']),
      episodeNum: asInt(json['episode_num']),
      title: asString(json['title']),
      containerExtension: asString(json['container_extension']),
      info: json['info'] is Map<String, dynamic>
          ? EpisodeInfo.fromJson(json['info'])
          : const EpisodeInfo(),
      added: asString(json['added']),
      season: asInt(json['season']),
      directSource: asString(json['direct_source']),
      watchProgress: json['watch_progress'] is Map<String, dynamic>
          ? WatchProgressModel.fromJson(
              json['watch_progress'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  String get displayTitle => (title != null && title!.trim().isNotEmpty)
      ? title!
      : 'Episode ${episodeNum ?? '-'}';
}

class EpisodeInfo {
  final String? movieImage;
  final String? plot;
  final String? releaseDate;
  final double? rating;
  final int? durationSecs;
  final String? duration;

  const EpisodeInfo({
    this.movieImage,
    this.plot,
    this.releaseDate,
    this.rating,
    this.durationSecs,
    this.duration,
  });

  factory EpisodeInfo.fromJson(Map<String, dynamic> json) {
    return EpisodeInfo(
      movieImage: asString(json['movie_image']),
      plot: asString(json['plot']),
      releaseDate: asString(json['releasedate']),
      rating: asDouble(json['rating']),
      durationSecs: asInt(json['duration_secs']),
      duration: asString(json['duration']),
    );
  }

  String get displayDuration =>
      (duration != null && duration!.isNotEmpty) ? duration! : '--:--';
}

class WatchProgressModel {
  final String resumePositionSeconds;
  final String durationSeconds;
  final String watchedPercent;
  final String fullyWatched;

  const WatchProgressModel({
    this.resumePositionSeconds = "0",
    this.durationSeconds = "0.0",
    this.watchedPercent = "0.0",
    this.fullyWatched = "false",
  });

  factory WatchProgressModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const WatchProgressModel();
    }

    return WatchProgressModel(
      resumePositionSeconds: json['resume_position_seconds']?.toString() ?? "0",
      durationSeconds: json['duration_seconds']?.toString() ?? "0",
      watchedPercent: json['watched_percent']?.toString() ?? "0.0",
      fullyWatched: json['fully_watched']?.toString() ?? "false",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'resume_position_seconds': resumePositionSeconds,
      'duration_seconds': durationSeconds,
      'watched_percent': watchedPercent,
      'fully_watched': fullyWatched,
    };
  }
}
