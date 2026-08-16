import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/tracked_entry.dart';
import '../models/update_event.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/cover_image.dart';
import '../widgets/error_view.dart';
import 'detail_screen.dart';

class TrackedScreen extends StatefulWidget {
  const TrackedScreen({super.key});

  @override
  State<TrackedScreen> createState() => _TrackedScreenState();
}

class _TrackedScreenState extends State<TrackedScreen> {
  int _tab = 0;
  List<TrackedEntry>? _tracked;
  String? _error;
  bool _loading = true;

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
      final items = await api.tracked();
      if (!mounted) return;
      setState(() {
        _tracked = items;
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final horizontal = Screen.horizontalPadding(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, Screen.verticalPadding(context), horizontal, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tracker',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (appState.connected)
                const _LiveBadge()
              else
                const _OfflineBadge(),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 4),
          child: SegmentedButton<int>(            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Dilacak'),
                icon: Icon(Icons.bookmark_rounded),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Notifikasi'),
                icon: Icon(Icons.notifications_rounded),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
            showSelectedIcon: false,
          ),
        ),
        Expanded(
          child: _tab == 0 ? _trackedList() : _eventsList(appState),
        ),
      ],
    );
  }

  Widget _trackedList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    final items = _tracked ?? [];
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Belum ada anime yang dilacak.'),
            const SizedBox(height: 4),
            Text(
              'Lacak dari halaman detail untuk dapat notifikasi.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          Screen.horizontalPadding(context),
          8,
          Screen.horizontalPadding(context),
          24 + Screen.bottomInset(context),
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final entry = items[index];
          return _TrackedTile(entry: entry);
        },
      ),
    );
  }

  Widget _eventsList(AppState appState) {
    final events = appState.events;
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Belum ada notifikasi update.'),
            const SizedBox(height: 4),
            Text(
              appState.connected
                  ? 'Terhubung ke server realtime, menunggu update...'
                  : 'Server tidak terhubung. Cek pengaturan server.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        Screen.horizontalPadding(context),
        8,
        Screen.horizontalPadding(context),
        24 + Screen.bottomInset(context),
      ),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _EventTile(event: event);
      },
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.circle, size: 10, color: Colors.green),
          SizedBox(width: 6),
          Text('Live', style: TextStyle(color: Colors.green)),
        ],
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.circle, size: 10, color: Colors.grey),
          SizedBox(width: 6),
          Text('Offline', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _TrackedTile extends StatelessWidget {
  final TrackedEntry entry;

  const _TrackedTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final anime = entry.anime;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => DetailScreen(animeId: anime.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              CoverImage(url: anime.coverMedium, width: 72, height: 102),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(
                            label: Text(anime.formatLabel,
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact),
                        Chip(
                            label: Text(anime.statusLabel,
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      anime.episodeLabel,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Hapus',
                onPressed: () async {
                  final api = context.read<ApiClient>();
                  await api.untrack(anime.id);
                  if (context.mounted) {
                    // trigger parent reload via a lightweight approach
                    (context.findAncestorStateOfType<_TrackedScreenState>())
                        ?._load();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final UpdateEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final anime = event.anime;
    final time = DateFormat('HH:mm').format(event.at);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (anime != null)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => DetailScreen(animeId: anime.id)),
                ),
                child: CoverImage(
                    url: anime.coverMedium, width: 56, height: 80),
              )
            else
              const Icon(Icons.notifications_rounded,
                  size: 40, color: AppTheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.note.isEmpty ? 'Update baru' : event.note,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (anime != null) ...[
                    const SizedBox(height: 4),
                    Text(anime.displayTitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.outline)),
                  ],
                ],
              ),
            ),
            Text(time,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
