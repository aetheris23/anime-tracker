import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/anime.dart';
import '../models/page_result.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/anime_grid.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _mode = 0;
  String? _status;
  String? _genre;
  String? _tag;
  List<String> _genres = [];
  List<String> _tags = [];
  bool _genresLoaded = false;
  bool _tagsLoaded = false;

  static const _statusOptions = <(String?, String)>[
    (null, 'Semua'),
    ('RELEASING', 'Tayang'),
    ('FINISHED', 'Selesai'),
    ('NOT_YET_RELEASED', 'Segera'),
  ];

  @override
  void initState() {
    super.initState();
    _loadGenres();
    _loadTags();
  }

  Future<void> _loadGenres() async {
    final api = context.read<ApiClient>();
    try {
      final genres = await api.genres();
      if (mounted) {
        setState(() {
          _genres = genres;
          _genresLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _genresLoaded = true);
    }
  }

  Future<void> _loadTags() async {
    final api = context.read<ApiClient>();
    try {
      final tags = await api.tags();
      if (mounted) {
        setState(() {
          _tags = tags;
          _tagsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _tagsLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = Screen.horizontalPadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, Screen.verticalPadding(context), horizontal, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anime Tracker',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            foreground: Paint()
                              ..shader = AppGradient.hero().createShader(
                                  const Rect.fromLTWH(0, 0, 220, 40)),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pantau rilis terbaru secara realtime',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: horizontal, vertical: 4),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Update Terkini'),
                icon: Icon(Icons.bolt_rounded),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Musim Ini'),
                icon: Icon(Icons.calendar_month_rounded),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
            showSelectedIcon: false,
          ),
        ),
        _filterBar(context),
        Expanded(
          child: AnimeGrid(
            key: ValueKey('grid-$_mode-$_status-$_genre-$_tag'),
            loader: _loadPage,
            onTap: _open,
          ),
        ),
      ],
    );
  }

  Widget _filterBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: Screen.horizontalPadding(context), vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (value, label) in _statusOptions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _status == value,
                      onSelected: (_) => setState(() => _status = value),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: _chipRow(
              loaded: _genresLoaded,
              items: _genres,
              selected: _genre,
              allLabel: 'Semua Genre',
              onSelected: (v) => setState(() => _genre = v),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: _chipRow(
              loaded: _tagsLoaded,
              items: _tags,
              selected: _tag,
              allLabel: 'Semua Kategori',
              onSelected: (v) => setState(() => _tag = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow({
    required bool loaded,
    required List<String> items,
    required String? selected,
    required String allLabel,
    required ValueChanged<String?> onSelected,
  }) {
    if (!loaded) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(allLabel),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(item),
              selected: selected == item,
              onSelected: (_) => onSelected(item),
            ),
          ),
      ],
    );
  }

  Future<PageResult> _loadPage(int page) async {
    final api = context.read<ApiClient>();
    final status = _status ?? '';
    final genre = _genre ?? '';
    final tag = _tag ?? '';
    if (_mode == 0) {
      return api.latest(
          status: status, genre: genre, tag: tag, page: page, perPage: 30);
    }
    return (await api.season(0,
            status: status, genre: genre, tag: tag, page: page, perPage: 30))
        .page;
  }

  void _open(Anime anime) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(animeId: anime.id)),
    );
  }
}
