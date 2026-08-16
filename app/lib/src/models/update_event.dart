import 'anime.dart';

class UpdateEvent {
  final String type;
  final String kind;
  final Anime? anime;
  final String note;
  final DateTime at;

  const UpdateEvent({
    required this.type,
    required this.kind,
    required this.anime,
    required this.note,
    required this.at,
  });

  factory UpdateEvent.fromJson(Map<String, dynamic> json) {
    final data = _asMap(json['data']);
    final anime = _asMap(data['anime']);
    return UpdateEvent(
      type: json['type'] as String? ?? '',
      kind: data['kind'] as String? ?? '',
      anime: anime.isEmpty ? null : Anime.fromJson(anime),
      note: data['note'] as String? ?? '',
      at: DateTime.tryParse(json['at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
