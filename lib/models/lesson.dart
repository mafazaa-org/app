import 'package:hive_flutter/hive_flutter.dart';

part 'lesson.g.dart';

@HiveType(typeId: 0)
class Lesson extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String youtubeUrl;

  @HiveField(2)
  final int order;

  @HiveField(3)
  final int month;

  @HiveField(4)
  final String title;

  @HiveField(5)
  final String thumbnailUrl;

  /// Locally-persisted progress flag — never comes from the remote curriculum.
  @HiveField(6)
  bool completed;

  /// The position of the lesson in the remote JSON file.
  @HiveField(7)
  final int position;

  /// Optional notification message from the remote curriculum.
  @HiveField(8)
  String? notification;

  /// Whether the user has read the notification for this lesson.
  @HiveField(9)
  bool read;

  /// Optional start time, in seconds from the beginning of the YouTube video.
  @HiveField(10)
  final int? startSecond;

  /// Optional end time, in seconds from the beginning of the YouTube video.
  @HiveField(11)
  final int? endSecond;

  /// Optional label for split videos, e.g. "Part 1".
  @HiveField(12)
  final String? partTitle;

  /// Optional numeric part index.
  @HiveField(13)
  final int? partNumber;

  Lesson({
    required this.id,
    required this.youtubeUrl,
    required this.order,
    required this.month,
    required this.title,
    required this.thumbnailUrl,
    required this.position,
    this.completed = false,
    this.notification,
    this.read = false,
    this.startSecond,
    this.endSecond,
    this.partTitle,
    this.partNumber,
  });

  String get displayTitle {
    final cleanPartTitle = partTitle?.trim();
    if (cleanPartTitle == null || cleanPartTitle.isEmpty) {
      return title;
    }

    return '$title - $cleanPartTitle';
  }

  bool get hasTimeRange => startSecond != null || endSecond != null;

  factory Lesson.fromJson(Map<String, dynamic> json, int position) => Lesson(
    id: json['id'] as String? ?? '',
    youtubeUrl: json['youtubeUrl'] as String? ?? '',
    order: (json['order'] as num?)?.toInt() ?? 0,
    month: (json['month'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    thumbnailUrl:
        (json['thumbnail_url'] ?? json['thumbnailUrl']) as String? ?? '',
    position: position,
    notification: json['notification'] as String?,
    startSecond: _readOptionalInt(json, [
      'startSecond',
      'startSeconds',
      'start',
    ]),
    endSecond: _readOptionalInt(json, ['endSecond', 'endSeconds', 'end']),
    partTitle: json['partTitle'] as String?,
    partNumber: _readOptionalInt(json, ['partNumber', 'part_number', 'part']),
  );
}

int? _readOptionalInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;

    if (value is num) return value.toInt();

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }

  return null;
}
