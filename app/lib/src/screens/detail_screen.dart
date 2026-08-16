import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models/anime.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/cover_image.dart';
import '../widgets/error_view.dart';

class DetailScreen extends StatefulWidget {
  final int animeId;

  const DetailScreen({super.key, required this.animeId});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Anime? _anime;
  bool _tracked = false;
  bool _loading = true;
  String? _error;
  bool _tracking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await api.detail(widget.animeId);
      if (!mounted) return;
      setState(() {
        _anime = Anime.fromJson(result['anime'] as Map<String, dynamic>);
        _tracked = result['tracked'] as bool? ?? false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleTrack() async {
    final api = context.read<ApiClient>();
    setState(() => _tracking = true);
    try {
      if (_tracked) {
        await api.untrack(widget.animeId);
      } else {
        await api.track(widget.animeId);
      }
      if (!mounted) return;
      setState(() => _tracked = !_tracked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tracked
              ? 'Ditandai, kamu akan dapat notifikasi update.'
              : 'Tidak lagi ditandai.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _tracking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _anime == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: _error ?? 'Tidak ditemukan', onRetry: _load),
      );
    }
    return _DetailBody(
      anime: _anime!,
      tracked: _tracked,
      tracking: _tracking,
      onToggleTrack: _toggleTrack,
      onReload: _load,
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Anime anime;
  final bool tracked;
  final bool tracking;
  final VoidCallback onToggleTrack;
  final VoidCallback onReload;

  const _DetailBody({
    required this.anime,
    required this.tracked,
    required this.tracking,
    required this.onToggleTrack,
    required this.onReload,
  });

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = Screen.isWide(context);
    final scheme = Theme.of(context).colorScheme;
    final horizontal = Screen.horizontalPadding(context);
    final bottomInset = Screen.bottomInset(context);

    final banner = SizedBox(
      height: isWide ? 260 : 190,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (anime.bannerImage.isNotEmpty)
            CoverImage(url: anime.bannerImage, borderRadius: 0)
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: AppGradient.hero()),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  scheme.surface.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: isWide ? 260 : 190,
            pinned: true,
            stretch: true,
            leading: const BackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: banner,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                0,
                horizontal,
                32 + bottomInset,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 760) {
                        return _wideLayout(context);
                      }
                      return _mobileLayout(context);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(0, -70),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CoverImage(
                url: anime.coverLarge,
                width: 130,
                height: 185,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(anime.fullTitle,
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MetaChip(icon: Icons.movie_outlined, label: anime.formatLabel),
                        if (anime.seasonYear != null)
                          _MetaChip(
                              icon: Icons.calendar_month_outlined,
                              label: '${anime.seasonYear}'),
                        if (anime.episodes != null)
                          _MetaChip(
                              icon: Icons.video_library_outlined,
                              label: anime.episodeLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _trackButton(context),
        const SizedBox(height: 16),
        _titleBlock(context, textTheme),
        const SizedBox(height: 16),
        _description(context),
        const SizedBox(height: 20),
        _genres(context),
        const SizedBox(height: 16),
        _infoBlock(context),
      ],
    );
  }

  Widget _wideLayout(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverImage(
              url: anime.coverLarge,
              width: 200,
              height: 285,
              borderRadius: 12,
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(anime.fullTitle,
                      style: textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MetaChip(icon: Icons.movie_outlined, label: anime.formatLabel),
                      _MetaChip(icon: Icons.play_circle_outline, label: anime.statusLabel),
                      if (anime.seasonYear != null)
                        _MetaChip(
                            icon: Icons.calendar_month_outlined,
                            label: '${anime.seasonYear}'),
                      if (anime.episodes != null)
                        _MetaChip(
                            icon: Icons.video_library_outlined,
                            label: anime.episodeLabel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _genres(context),
                  const SizedBox(height: 16),
                  _trackButton(context),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _description(context),
        const SizedBox(height: 20),
        _infoBlock(context),
      ],
    );
  }

  Widget _titleBlock(BuildContext context, TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: Text(anime.fullTitle,
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
        if (anime.averageScore != null) ...[
          const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
          Text('${anime.averageScore}%',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, color: Colors.amber)),
        ],
      ],
    );
  }

  Widget _trackButton(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: tracking ? null : onToggleTrack,
            icon: tracking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(tracked
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded),
            label: Text(tracked
                ? 'Dilacak — dapatkan notifikasi'
                : 'Lacak anime ini'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (anime.siteUrl.isNotEmpty) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () => _open(anime.siteUrl),
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Buka di AniList',
          ),
        ],
      ],
    );
  }

  Widget _description(BuildContext context) {
    final text = _stripHtml(anime.description);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sinopsis',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              text.isEmpty ? 'Belum ada sinopsis.' : text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.55),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genres(BuildContext context) {
    if (anime.genres.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: anime.genres
          .map((g) => Chip(label: Text(g)))
          .toList(),
    );
  }

  Widget _infoBlock(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = <(IconData, String, String)>[
      (Icons.category_outlined, 'Status', anime.statusLabel),
      if (anime.season != null && anime.seasonYear != null)
        (Icons.event_outlined, 'Musim', '${_seasonLabel(anime.season!)} ${anime.seasonYear}'),
      (Icons.theaters_outlined, 'Format', anime.formatLabel),
      if (anime.episodes != null)
        (Icons.video_library_outlined, 'Episode', '${anime.episodes}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detail',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                for (final (icon, label, value) in rows)
                  ListTile(
                    dense: true,
                    leading: Icon(icon, size: 20),
                    title: Text(label),
                    trailing: Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                if (anime.studios.isNotEmpty)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.business_rounded, size: 20),
                    title: const Text('Studio'),
                    trailing: Text(anime.studios.join(', '),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _seasonLabel(String season) {
    switch (season) {
      case 'WINTER':
        return 'Winter';
      case 'SPRING':
        return 'Spring';
      case 'SUMMER':
        return 'Summer';
      case 'FALL':
        return 'Fall';
      default:
        return season;
    }
  }

  String _stripHtml(String input) {
    if (input.isEmpty) return input;
    final withoutTags = input.replaceAll(RegExp(r'<[^>]*>'), '');
    return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
