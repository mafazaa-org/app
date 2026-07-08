// lib/models/lesson_group.dart
import 'lesson.dart';

/// Groups lessons that share the same [month] and [order] into a single
/// curriculum step. A step with more than one lesson is a "double lesson".
class LessonGroup {
  final int month;
  final int order;
  final List<Lesson> lessons;

  const LessonGroup({
    required this.month,
    required this.order,
    required this.lessons,
  });

  bool get isCompleted => lessons.every((l) => l.completed);
  bool get hasMultiple => lessons.length > 1;
  int get completedCount => lessons.where((l) => l.completed).length;

  /// Builds sorted groups from a flat, already-sorted list of lessons.
  static List<LessonGroup> fromLessons(List<Lesson> lessons) {
    final map = <String, List<Lesson>>{};
    for (final lesson in lessons) {
      map.putIfAbsent('${lesson.month}_${lesson.order}', () => []).add(lesson);
    }
    final groups = map.entries.map((e) {
      final parts = e.key.split('_');
      return LessonGroup(
        month: int.parse(parts[0]),
        order: int.parse(parts[1]),
        lessons: e.value,
      );
    }).toList()
      ..sort((a, b) {
        final m = a.month.compareTo(b.month);
        return m != 0 ? m : a.order.compareTo(b.order);
      });
    return groups;
  }
}
