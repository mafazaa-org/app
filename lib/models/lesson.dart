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
  /// Set to null when removed from the online file.
  @HiveField(8)
  String? notification;

  /// Whether the user has read the notification for this lesson.
  /// Automatically reset to false when [completed] becomes true.
  @HiveField(9)
  bool read;

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
  });

  factory Lesson.fromJson(Map<String, dynamic> json, int position) => Lesson(
        id: json['id'] as String? ?? '',
        youtubeUrl: json['youtubeUrl'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        month: (json['month'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        thumbnailUrl:
            (json['thumbnail_url'] ?? json['thumbnailUrl']) as String? ?? '',
        position: position,
        // notification comes from remote; read is always local-only
        notification: json['notification'] as String?,
      );
}