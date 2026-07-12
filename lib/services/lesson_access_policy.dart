import '../models/lesson.dart';

/// Keeps curriculum navigation sequential while allowing completed lessons to
/// be opened again at any time.
class LessonAccessPolicy {
  const LessonAccessPolicy._();

  static bool isUnlocked(List<Lesson> lessons, Lesson lesson) {
    final index = lessons.indexWhere((item) => item.id == lesson.id);
    if (index < 0) return false;
    if (lesson.completed || index == 0) return true;

    return lessons.take(index).every((item) => item.completed);
  }

  /// Returns the first unfinished lesson that blocks [lesson], if any.
  static Lesson? blockingLesson(List<Lesson> lessons, Lesson lesson) {
    final index = lessons.indexWhere((item) => item.id == lesson.id);
    if (index <= 0 || lesson.completed) return null;

    for (final previous in lessons.take(index)) {
      if (!previous.completed) return previous;
    }
    return null;
  }

  /// The lesson that should be selected when the curriculum screen opens.
  static Lesson? currentLesson(List<Lesson> lessons) {
    if (lessons.isEmpty) return null;
    return lessons.firstWhere(
      (lesson) => !lesson.completed,
      orElse: () => lessons.first,
    );
  }
}
