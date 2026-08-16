import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/api/api_client.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/search_screen.dart';
import 'src/screens/settings_screen.dart';
import 'src/screens/tracked_screen.dart';
import 'src/services/notification_service.dart';
import 'src/state/app_state.dart';
import 'src/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationService = NotificationService();
  final appState = AppState(
    api: ApiClient(baseUrlProvider: () => ''),
    notificationService: notificationService,
  );
  runApp(AnimeTrackerApp(appState: appState));
}

class AnimeTrackerApp extends StatelessWidget {
  final AppState appState;

  const AnimeTrackerApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        Provider<ApiClient>.value(value: appState.api),
      ],
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'Anime Tracker',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: state.darkMode ? ThemeMode.dark : ThemeMode.light,
          home: const RootShell(),
        ),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final state = context.read<AppState>();
    await state.init();
    await state.notificationService.init();
    state.startRealtime();
    unawaited(state.syncTrackedCatchUp());
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Menyiapkan Anime Tracker...'),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        if (wide) {
          return const _RailLayout();
        }
        return const _BarLayout();
      },
    );
  }
}

class _BarLayout extends StatelessWidget {
  const _BarLayout();

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<AppState>().tab;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _bodyForKey(tab),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab.index,
        onDestinationSelected: (i) =>
            context.read<AppState>().setTab(AppTab.values[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Cari',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Tracker',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Atur',
          ),
        ],
      ),
    );
  }
}

class _RailLayout extends StatelessWidget {
  const _RailLayout();

  @override
  Widget build(BuildContext context) {
    final tab = context.watch<AppState>().tab;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            NavigationRail(
              extended: true,
              minExtendedWidth: 200,
              selectedIndex: tab.index,
              onDestinationSelected: (i) =>
                  context.read<AppState>().setTab(AppTab.values[i]),
              labelType: NavigationRailLabelType.none,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppGradient.hero(),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.movie_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Anime Tracker',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Beranda'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search_outlined),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: Text('Cari'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bookmark_outline_rounded),
                  selectedIcon: Icon(Icons.bookmark_rounded),
                  label: Text('Tracker'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: Text('Atur'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _bodyForKey(tab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _bodyForKey(AppTab tab) {
  switch (tab) {
    case AppTab.home:
      return const HomeScreen(key: ValueKey('home'));
    case AppTab.search:
      return const SearchScreen(key: ValueKey('search'));
    case AppTab.tracked:
      return const TrackedScreen(key: ValueKey('tracked'));
    case AppTab.settings:
      return const SettingsScreen(key: ValueKey('settings'));
  }
}
