// lib/models/lesson.dart
import 'package:hive_flutter/hive_flutter.dart';

part 'lesson.g.dart';

@HiveType(typeId: 0)
class Lesson extends HiveObject {

  @HiveField(0)
  String youtubeUrl;

  Lesson({
    required this.youtubeUrl,
  });
}