import 'package:flutter_test/flutter_test.dart';

import 'package:anime_tracker/src/models/anime.dart';
import 'package:anime_tracker/src/models/page_result.dart';
import 'package:anime_tracker/src/theme/app_theme.dart';

void main() {
  test('Anime.fromJson parses fields correctly', () {
    final anime = Anime.fromJson({
      'id': 21,
      'title': {'romaji': 'ONE PIECE', 'english': 'ONE PIECE', 'native': 'ONE PIECE'},
      'coverImage': {
        'extraLarge': 'https://x/large.jpg',
        'large': 'https://x/med.jpg',
        'medium': 'https://x/small.jpg',
      },
      'description': '<p>Pirate story</p>',
      'averageScore': 87,
      'genres': ['Action', 'Adventure'],
      'episodes': 1000,
      'season': 'SUMMER',
      'seasonYear': 1999,
      'format': 'TV',
      'status': 'RELEASING',
      'startDate': {'year': 1999, 'month': 10, 'day': 20},
      'updatedAt': 1700000000,
      'studios': {
        'nodes': [
          {'name': 'Toei Animation'}
        ]
      },
      'isAdult': false,
    });

    expect(anime.id, 21);
    expect(anime.displayTitle, 'ONE PIECE');
    expect(anime.genres, contains('Action'));
    expect(anime.statusLabel, 'Tayang');
    expect(anime.formatLabel, 'TV');
    expect(anime.episodes, 1000);
    expect(anime.isAdult, false);
  });

  test('PageResult.fromJson handles Go backend envelope', () {
    final result = PageResult.fromJson({
      'Anime': [
        {
          'id': 1,
          'title': {'romaji': 'Cowboy Bebop'},
          'coverImage': {},
          'genres': [],
          'startDate': {},
          'studios': {'nodes': []},
          'updatedAt': 0,
          'isAdult': false,
        }
      ],
      'pageInfo': {'total': 1, 'currentPage': 1, 'lastPage': 1, 'hasNextPage': false},
    });

    expect(result.anime, hasLength(1));
    expect(result.anime.first.displayTitle, 'Cowboy Bebop');
    expect(result.pageInfo.hasNextPage, false);
  });

  test('AppTheme exposes valid themes', () {
    expect(AppTheme.dark(), isNotNull);
    expect(AppTheme.light(), isNotNull);
  });
}
