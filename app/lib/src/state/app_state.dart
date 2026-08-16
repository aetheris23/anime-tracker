import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/update_event.dart';
import '../services/notification_service.dart';

enum AppTab { home, search, tracked, settings }

class AppState extends ChangeNotifier {
  static const _kBaseUrl = 'base_url';
  static const _kDark = 'dark_mode';
  static const _kDefaultBaseUrl = 'http://192.168.1.101:8080';

  final ApiClient api;
  final NotificationService notificationService;
  RealtimeService? realtime;

  String baseUrl = _kDefaultBaseUrl;
  bool darkMode = true;
  bool connected = false;
  final List<UpdateEvent> events = [];
  AppTab tab = AppTab.home;

  AppState({
    required this.api,
    required this.notificationService,
  });

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_kBaseUrl) ?? _kDefaultBaseUrl;
    darkMode = prefs.getBool(_kDark) ?? true;
    api.baseUrlProvider = () => baseUrl;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty) return;
    baseUrl = cleaned;
    api.baseUrlProvider = () => baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, cleaned);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDark, value);
    notifyListeners();
  }

  void setTab(AppTab tab) {
    if (this.tab == tab) return;
    this.tab = tab;
    notifyListeners();
  }

  void startRealtime() {
    realtime?.stop();
    realtime = RealtimeService(
      baseUrlProvider: () => baseUrl,
      onEvent: _onEvent,
      onConnectionChanged: (c) {
        connected = c;
        notifyListeners();
      },
    );
    realtime?.start();
  }

  void _onEvent(UpdateEvent event) {
    events.insert(0, event);
    if (events.length > 50) {
      events.removeRange(50, events.length);
    }
    if (event.type == 'update' &&
        event.kind == 'tracked' &&
        event.anime != null) {
      notificationService.showTrackedUpdate(event.anime!, event.note);
    }
    notifyListeners();
  }

  Future<void> syncTrackedCatchUp() async {
    try {
      final entries = await api.tracked();
      for (final entry in entries) {
        await notificationService.storeBaseline(entry);
      }
      await notificationService.syncTracked(entries);
    } catch (_) {
      // ignore sync errors; realtime events cover the rest
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await notificationService.setEnabled(value);
    notifyListeners();
  }

  bool get notificationsEnabled => notificationService.enabled;
}
