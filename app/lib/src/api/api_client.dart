import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/page_result.dart';
import '../models/tracked_entry.dart';
import '../models/update_event.dart';
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  String Function() baseUrlProvider;

  ApiClient({required this.baseUrlProvider});

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrlProvider().trim().replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<dynamic> _get(String path, [Map<String, String>? query]) async {
    try {
      final res = await http
          .get(_uri(path, query), headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _decode(res);
    } on TimeoutException {
      throw const ApiException(0, 'Waktu habis, cek koneksi ke server.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(0, 'Tidak dapat terhubung ke server: $e');
    }
  }

  Future<dynamic> _send(
      String method, String path, Map<String, dynamic> body) async {
    try {
      final client = http.Client();
      try {
        final request = http.Request(method, _uri(path))
          ..headers.addAll(_headers)
          ..body = jsonEncode(body);
        final streamed = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
        final res = await http.Response.fromStream(streamed);
        return _decode(res);
      } finally {
        client.close();
      }
    } on TimeoutException {
      throw const ApiException(0, 'Waktu habis, cek koneksi ke server.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(0, 'Tidak dapat terhubung ke server: $e');
    }
  }

  dynamic _decode(http.Response res) {
    final dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw ApiException(res.statusCode, 'Respon server tidak valid.');
    }
    if (res.statusCode >= 400) {
      final err = json is Map<String, dynamic>
          ? json['error'] is Map<String, dynamic>
              ? json['error']['message']
              : null
          : null;
      throw ApiException(res.statusCode, err ?? 'Error ${res.statusCode}');
    }
    return json;
  }

  Future<PageResult> search({
    String search = '',
    String genre = '',
    String tag = '',
    String status = '',
    String sort = '',
    int page = 1,
    int perPage = 24,
  }) async {
    final json = await _get('/api/anime', {
      if (search.isNotEmpty) 'search': search,
      if (genre.isNotEmpty) 'genre': genre,
      if (tag.isNotEmpty) 'tag': tag,
      if (status.isNotEmpty) 'status': status,
      if (sort.isNotEmpty) 'sort': sort,
      'page': '$page',
      'perPage': '$perPage',
    });
    return PageResult.fromJson(json as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> detail(int id) async {
    final json = await _get('/api/anime/$id');
    return json as Map<String, dynamic>;
  }

  Future<SeasonResult> season(int offset,
      {String status = '', String genre = '', String tag = '', int page = 1, int perPage = 24}) async {
    final json = await _get('/api/season/$offset', {
      if (status.isNotEmpty) 'status': status,
      if (genre.isNotEmpty) 'genre': genre,
      if (tag.isNotEmpty) 'tag': tag,
      'page': '$page',
      'perPage': '$perPage',
    });
    return SeasonResult.fromJson(json as Map<String, dynamic>);
  }

  Future<PageResult> latest(
      {String status = '', String genre = '', String tag = '', int page = 1, int perPage = 24}) async {
    final json = await _get('/api/latest', {
      if (status.isNotEmpty) 'status': status,
      if (genre.isNotEmpty) 'genre': genre,
      if (tag.isNotEmpty) 'tag': tag,
      'page': '$page',
      'perPage': '$perPage',
    });
    return PageResult.fromJson(json as Map<String, dynamic>);
  }

  Future<List<String>> genres() async {
    final json = await _get('/api/genres');
    final list = (json as Map<String, dynamic>)['genres'] as List<dynamic>? ?? [];
    return list.cast<String>();
  }

  Future<List<String>> tags() async {
    final json = await _get('/api/tags');
    final list = (json as Map<String, dynamic>)['tags'] as List<dynamic>? ?? [];
    return list.cast<String>();
  }

  Future<List<TrackedEntry>> tracked() async {
    final json = await _get('/api/tracked');
    return (json as List<dynamic>)
        .map((e) => TrackedEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> track(int id) async {
    await _send('POST', '/api/track', {'id': id});
  }

  Future<void> untrack(int id) async {
    await _send('DELETE', '/api/track/$id', {});
  }

  Future<Map<String, dynamic>> status() async {
    final json = await _get('/api/status');
    return json as Map<String, dynamic>;
  }

  Future<void> health() async {
    await _get('/api/health');
  }
}

class RealtimeService {
  String Function() baseUrlProvider;
  final void Function(UpdateEvent event) onEvent;
  final void Function(bool connected)? onConnectionChanged;

  StreamSubscription<List<int>>? _sub;
  bool _active = false;
  bool _connected = false;

  RealtimeService({
    required this.baseUrlProvider,
    required this.onEvent,
    this.onConnectionChanged,
  });

  bool get isActive => _active;

  void start() {
    if (_active) return;
    _active = true;
    _connect();
  }

  void stop() {
    _active = false;
    _connected = false;
    _sub?.cancel();
    _sub = null;
    onConnectionChanged?.call(false);
  }

  Future<void> _connect() async {
    while (_active) {
      try {
        final base =
            baseUrlProvider().trim().replaceAll(RegExp(r'/+$'), '');
        final request =
            http.Request('GET', Uri.parse('$base/api/stream'));
        final client = http.Client();
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          client.close();
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }
        if (!_connected) {
          _connected = true;
          onConnectionChanged?.call(true);
        }
        final completer = Completer<void>();
        _sub = response.stream.timeout(const Duration(seconds: 90)).listen(
              (chunk) => _parseChunk(chunk),
              onDone: () {
                client.close();
                completer.complete();
              },
              onError: (_) {
                client.close();
                completer.complete();
              },
            );
        await completer.future;
        _connected = false;
        onConnectionChanged?.call(false);
        client.close();
      } catch (_) {
        _connected = false;
        onConnectionChanged?.call(false);
      }
      if (_active) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  String _buffer = '';

  void _parseChunk(List<int> bytes) {
    _buffer += utf8.decode(bytes, allowMalformed: true);
    while (true) {
      final idx = _buffer.indexOf('\n\n');
      if (idx < 0) break;
      final block = _buffer.substring(0, idx).trim();
      _buffer = _buffer.substring(idx + 2);
      _handleBlock(block);
    }
    if (_buffer.length > 1 << 20) {
      _buffer = '';
    }
  }

  void _handleBlock(String block) {
    final dataLines = <String>[];
    for (final line in block.split('\n')) {
      if (line.startsWith('data: ')) {
        dataLines.add(line.substring(6));
      }
    }
    if (dataLines.isEmpty) return;
    final raw = dataLines.join('\n');
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final event = UpdateEvent.fromJson(json);
      if (event.type == 'update' && event.anime != null) {
        onEvent(event);
      }
    } catch (_) {
      // ignore malformed frames
    }
  }
}
