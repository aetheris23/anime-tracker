import 'anime.dart';

class PageInfo {
  final int total;
  final int currentPage;
  final int lastPage;
  final bool hasNextPage;

  const PageInfo({
    required this.total,
    required this.currentPage,
    required this.lastPage,
    required this.hasNextPage,
  });

  factory PageInfo.fromJson(Map<String, dynamic> json) => PageInfo(
        total: json['total'] as int? ?? 0,
        currentPage: json['currentPage'] as int? ?? 1,
        lastPage: json['lastPage'] as int? ?? 1,
        hasNextPage: json['hasNextPage'] as bool? ?? false,
      );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

class PageResult {
  final List<Anime> anime;
  final PageInfo pageInfo;

  const PageResult({required this.anime, required this.pageInfo});

  factory PageResult.fromJson(Map<String, dynamic> json) {
    final page = _asMap(json['page']);
    if (page.isEmpty) {
      page.addAll(json);
    }
    final media = page['media'] as List<dynamic>? ?? page['Anime'] as List<dynamic>? ?? [];
    final info = _asMap(page['pageInfo']);

    return PageResult(
      anime: media
          .whereType<Map>()
          .map((m) => Anime.fromJson(_asMap(m)))
          .toList(),
      pageInfo: PageInfo.fromJson(info),
    );
  }
}

class SeasonResult {
  final String season;
  final int year;
  final PageResult page;

  const SeasonResult({
    required this.season,
    required this.year,
    required this.page,
  });

  factory SeasonResult.fromJson(Map<String, dynamic> json) => SeasonResult(
        season: json['season'] as String? ?? '',
        year: json['year'] as int? ?? 0,
        page: PageResult.fromJson(json),
      );
}
