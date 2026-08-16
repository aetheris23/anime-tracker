class FuzzyDate {
  final int? year;
  final int? month;
  final int? day;

  const FuzzyDate({this.year, this.month, this.day});

  factory FuzzyDate.fromJson(Map<String, dynamic> json) => FuzzyDate(
        year: json['year'] as int?,
        month: json['month'] as int?,
        day: json['day'] as int?,
      );
}

class Anime {
  final int id;
  final String romaji;
  final String english;
  final String native;
  final String coverLarge;
  final String coverMedium;
  final String bannerImage;
  final String description;
  final int? averageScore;
  final List<String> genres;
  final int? episodes;
  final String? season;
  final int? seasonYear;
  final String format;
  final String status;
  final FuzzyDate startDate;
  final int updatedAt;
  final List<String> studios;
  final String siteUrl;
  final bool isAdult;

  const Anime({
    required this.id,
    required this.romaji,
    required this.english,
    required this.native,
    required this.coverLarge,
    required this.coverMedium,
    required this.bannerImage,
    required this.description,
    required this.averageScore,
    required this.genres,
    required this.episodes,
    required this.season,
    required this.seasonYear,
    required this.format,
    required this.status,
    required this.startDate,
    required this.updatedAt,
    required this.studios,
    required this.siteUrl,
    required this.isAdult,
  });

  String get displayTitle {
    final romaji = this.romaji.trim();
    if (romaji.isNotEmpty) return romaji;
    final english = this.english.trim();
    if (english.isNotEmpty) return english;
    return native.isNotEmpty ? native : 'Untitled';
  }

  String get fullTitle {
    final parts = <String>[];
    if (english.trim().isNotEmpty) parts.add(english.trim());
    if (romaji.trim().isNotEmpty && romaji.trim() != english.trim()) {
      parts.add(romaji.trim());
    }
    if (parts.isEmpty) parts.add(native);
    return parts.join('\n');
  }

  String get statusLabel {
    switch (status) {
      case 'FINISHED':
        return 'Selesai';
      case 'RELEASING':
        return 'Tayang';
      case 'NOT_YET_RELEASED':
        return 'Belum Rilis';
      case 'CANCELLED':
        return 'Dibatalkan';
      case 'HIATUS':
        return 'Istirahat';
      default:
        return status;
    }
  }

  String get formatLabel {
    switch (format) {
      case 'TV':
        return 'TV';
      case 'MOVIE':
        return 'Movie';
      case 'OVA':
        return 'OVA';
      case 'ONA':
        return 'ONA';
      case 'TV_SHORT':
        return 'TV Short';
      case 'SPECIAL':
        return 'Special';
      case 'MUSIC':
        return 'Music';
      default:
        return format;
    }
  }

  String get episodeLabel {
    if (episodes == null) return '?';
    return '$episodes eps';
  }

  factory Anime.fromJson(Map<String, dynamic> json) {
    final title = _asMap(json['title']);
    final cover = _asMap(json['coverImage']);
    final studios = _asMap(json['studios']);
    final nodes = studios['nodes'] as List<dynamic>? ?? [];

    return Anime(
      id: json['id'] as int,
      romaji: title['romaji'] as String? ?? '',
      english: title['english'] as String? ?? '',
      native: title['native'] as String? ?? '',
      coverLarge: cover['extraLarge'] as String? ?? cover['large'] as String? ?? '',
      coverMedium: cover['large'] as String? ?? cover['medium'] as String? ?? '',
      bannerImage: json['bannerImage'] as String? ?? '',
      description: json['description'] as String? ?? '',
      averageScore: json['averageScore'] as int?,
      genres: (json['genres'] as List<dynamic>? ?? []).cast<String>(),
      episodes: json['episodes'] as int?,
      season: json['season'] as String?,
      seasonYear: json['seasonYear'] as int?,
      format: json['format'] as String? ?? '',
      status: json['status'] as String? ?? '',
      startDate: FuzzyDate.fromJson(_asMap(json['startDate'])),
      updatedAt: (json['updatedAt'] as int? ?? 0) * 1000,
      studios: nodes
          .whereType<Map>()
          .map((n) => _asMap(n)['name'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList(),
      siteUrl: json['siteUrl'] as String? ?? '',
      isAdult: json['isAdult'] as bool? ?? false,
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
