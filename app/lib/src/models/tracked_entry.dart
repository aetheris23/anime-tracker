import 'anime.dart';

class TrackedEntry {
  final Anime anime;
  final DateTime addedAt;

  const TrackedEntry({required this.anime, required this.addedAt});

  factory TrackedEntry.fromJson(Map<String, dynamic> json) => TrackedEntry(
        anime: Anime.fromJson(_asMap(json['anime'])),
        addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}
