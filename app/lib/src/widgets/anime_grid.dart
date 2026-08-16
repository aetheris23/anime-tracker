import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/anime.dart';
import '../models/page_result.dart';
import '../utils/responsive.dart';
import 'anime_card.dart';
import 'error_view.dart';

class AnimeGrid extends StatefulWidget {
  final Future<PageResult> Function(int page) loader;
  final void Function(Anime anime)? onTap;
  final int baseColumns;

  const AnimeGrid({
    super.key,
    required this.loader,
    this.onTap,
    this.baseColumns = 2,
  });

  @override
  State<AnimeGrid> createState() => _AnimeGridState();
}

class _AnimeGridState extends State<AnimeGrid> {
  final _scroll = ScrollController();
  final List<Anime> _items = [];
  PageInfo? _pageInfo;
  bool _loading = false;
  bool _initialLoading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      _loadNext();
    }
  }

  Future<void> refresh() async {
    await _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    final id = ++_requestId;
    final page = reset ? 1 : (_pageInfo?.currentPage ?? 1) + 1;
    if (!reset && (_pageInfo?.hasNextPage ?? false) == false) return;

    setState(() {
      _loading = true;
      if (reset) _initialLoading = true;
    });
    try {
      final result = await widget.loader(page);
      if (!mounted || id != _requestId) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result.anime);
        } else {
          _items.addAll(result.anime);
        }
        _pageInfo = result.pageInfo;
        _error = null;
        _initialLoading = false;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.message;
        _initialLoading = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = 'Terjadi kesalahan: $e';
        _initialLoading = false;
        _loading = false;
      });
    }
  }

  void _loadNext() => _load(reset: false);

  int _columns(double width) {
    if (width >= 1400) return 6;
    if (width >= 1000) return 5;
    if (width >= 760) return 4;
    if (width >= 560) return 3;
    return widget.baseColumns;
  }

  double _cardWidth(double width, int columns, double spacing, double padding) {
    return (width - padding * 2 - spacing * (columns - 1)) / columns;
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ErrorView(
        message: _error!,
        onRetry: refresh,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = Screen.horizontalPadding(context);
        final spacing = constraints.maxWidth >= 760 ? 18.0 : 12.0;
        final columns = _columns(constraints.maxWidth);
        final cardWidth =
            _cardWidth(constraints.maxWidth, columns, spacing, padding);
        final textScale = MediaQuery.textScalerOf(context).scale(14);

        return RefreshIndicator(
          onRefresh: refresh,
          child: GridView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding, 8, padding, 24 + Screen.bottomInset(context)),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 20,
              crossAxisSpacing: spacing,
              mainAxisExtent: cardWidth * 1.4 + 58 * textScale.clamp(1.0, 1.6),
            ),
            itemCount: _items.length + (_pageInfo?.hasNextPage ?? false ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _items.length) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }
              final anime = _items[index];
              return AnimeCard(
                anime: anime,
                width: cardWidth,
                onTap: widget.onTap != null ? () => widget.onTap!(anime) : null,
              );
            },
          ),
        );
      },
    );
  }
}
