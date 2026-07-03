import 'package:hive_flutter/hive_flutter.dart';
import '../models/lesson.dart';

class LessonService {
  static const String lessonBox = 'lessons';

  LazyBox<Lesson> get _box => Hive.lazyBox<Lesson>(lessonBox);

  // جلب درس واحد
  Future<Lesson?> getLesson(String id) async {
    return await _box.get(id);
  }

  // جلب كل الدروس (بشكل تدريجي - لا تحمل كل شيء دفعة واحدة)
  Future<List<Lesson>> getAllLessons() async {
    final keys = _box.keys;
    final List<Lesson> lessons = [];
    for (var key in keys) {
      final lesson = await _box.get(key);
      if (lesson != null) lessons.add(lesson);
    }
    return lessons;
  }

  
}