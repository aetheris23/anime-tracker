import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/anime.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/anime_grid.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _genre = '';
  String _sort = '';
  AnimeGrid? _grid;
  int _gridKey = 0;

  static const _sorts = [
    ('', 'Populer'),
    ('TRENDING_DESC', 'Trending'),
    ('SCORE_DESC', 'Skor Tertinggi'),
    ('START_DATE_DESC', 'Terbaru'),
  ];

  static const _genres = [
    '',
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
    'Horror',
    'Mecha',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
  ];

  @override
  void initState() {
    super.initState();
    _grid = _buildGrid();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  AnimeGrid _buildGrid() {
    final api = context.read<ApiClient>();
    return AnimeGrid(
      key: PageStorageKey('search_$_gridKey'),
      loader: (page) => api.search(
        search: _query,
        genre: _genre,
        sort: _sort,
        page: page,
        perPage: 30,
      ),
      onTap: _open,
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _gridKey++;
        _grid = _buildGrid();
      });
    });
  }

  void _setFilter({String? genre, String? sort}) {
    setState(() {
      if (genre != null) _genre = genre;
      if (sort != null) _sort = sort;
      _gridKey++;
      _grid = _buildGrid();
    });
  }

  void _open(Anime anime) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(animeId: anime.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = Screen.horizontalPadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, Screen.verticalPadding(context), horizontal, 8),
          child: Text(
            'Cari Anime',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: TextField(
            controller: _controller,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari judul anime...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                    ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 8),
            children: [
              _FilterChip(
                label: _sortLabel(_sort),
                icon: Icons.sort_rounded,
                selected: _sort.isNotEmpty,
                onTap: () => _showSheet(
                  title: 'Urutkan',
                  options: _sorts
                      .map((s) => (s.$2, s.$1 == _sort))
                      .toList(),
                  onSelect: (v) => _setFilter(sort: v),
                ),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: _genre.isEmpty ? 'Semua Genre' : _genre,
                icon: Icons.category_rounded,
                selected: _genre.isNotEmpty,
                onTap: () => _showSheet(
                  title: 'Pilih Genre',
                  options: _genres.map((g) => (g.isEmpty ? 'Semua Genre' : g, g == _genre)).toList(),
                  onSelect: (v) => _setFilter(genre: v),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _grid ?? const SizedBox()),
      ],
    );
  }

  String _sortLabel(String sort) {
    for (final s in _sorts) {
      if (s.$1 == sort) return s.$2;
    }
    return 'Populer';
  }

  Future<void> _showSheet({
    required String title,
    required List<(String, bool)> options,
    required ValueChanged<String> onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final (label, selected) = options[index];
                  return ListTile(
                    title: Text(label),
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppTheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(label == 'Semua Genre' ? '' : label);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: selected ? AppTheme.primary.withValues(alpha: 0.18) : null,
        labelStyle: TextStyle(
          color: selected ? AppTheme.primary : scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
