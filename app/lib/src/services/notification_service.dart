import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/anime.dart';
import '../models/tracked_entry.dart';

class NotificationService {
  static const _enabledKey = 'notifications_enabled';
  static const _episodePrefix = 'last_ep_';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool enabled = true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_enabledKey) ?? true;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    );
    await _plugin.initialize(settings: settings);
    await _requestPermission();
  }

  Future<void> _requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> showTrackedUpdate(Anime anime, String note) async {
    if (!enabled) return;
    await _plugin.show(
      id: anime.id,
      title: 'Update: ${anime.displayTitle}',
      body: note.isEmpty ? 'Ada pembaruan untuk anime yang kamu lacak.' : note,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'tracker_updates',
          'Update Anime',
          channelDescription: 'Pemberitahuan episode/status anime yang dilacak',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
      ),
    );
  }

  Future<void> syncTracked(List<TrackedEntry> entries) async {
    if (!enabled) return;
    final prefs = await SharedPreferences.getInstance();
    for (final entry in entries) {
      final anime = entry.anime;
      final eps = anime.episodes;
      if (eps == null) continue;
      final key = _episodePrefix + anime.id.toString();
      final stored = prefs.getInt(key);
      if (stored != null && eps > stored) {
        await showTrackedUpdate(
          anime,
          stored == 0 ? 'Episode baru tayang (episode $eps)' : 'Episode baru tayang (episode $stored -> $eps)',
        );
      }
      await prefs.setInt(key, eps);
    }
  }

  Future<void> storeBaseline(TrackedEntry entry) async {
    final anime = entry.anime;
    final eps = anime.episodes;
    if (eps == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _episodePrefix + anime.id.toString();
    if (prefs.getInt(key) == null) {
      await prefs.setInt(key, eps);
    }
  }
}
