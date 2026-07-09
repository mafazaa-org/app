import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/lesson.dart';

class LessonService {
  static const String _lessonBox = 'lessons';
  static const String _curriculumUrl =
      'https://api.npoint.io/2035ddb6c563a8a7b572';

  LazyBox<Lesson> get _box => Hive.lazyBox<Lesson>(_lessonBox);

  /// Bootstraps lessons from the remote curriculum, syncing safely without
  /// losing locally-stored completion state. Fire-and-forget after the first
  /// cold start when the box already has data so startup stays fast.
  Future<void> initializeLessons() async {
    try {
      // Self-healing check: Test if we can read the first stored lesson.
      // If there's an incompatible legacy database schema on disk, it will throw
      // a type cast exception (Null is not a subtype of int) inside the read adapter.
      // We catch this and clear the box to heal it, then do a clean remote fetch.
      if (_box.isNotEmpty) {
        try {
          final firstKey = _box.keys.first;
          await _box.get(firstKey);
        } catch (e) {
          debugPrint(
            '[LessonService] Legacy schema mismatch detected during initialization. Clearing box: $e',
          );
          await _box.clear();
        }
      }

      final bool isEmpty = _box.isEmpty;
      if (isEmpty) {
        // First launch — block on the network fetch so the UI always has data.
        await syncWithRemote();
      } else {
        // Already have data — sync in the background without delaying startup.
        syncWithRemote();
      }
    } catch (e) {
      debugPrint('[LessonService] Error initializing lessons: $e');
    }
  }

  /// Deprecated local bootstrap loading replaced by remote curriculum syncing.
  /// Fetches the remote curriculum and merges it into the local Hive box,
  /// preserving the [Lesson.completed] flag for all existing lessons.
  Future<void> syncWithRemote() async {
    try {
      final response = await http.get(Uri.parse(_curriculumUrl));
      if (response.statusCode == 200) {
        final List<dynamic> remoteJson =
            json.decode(response.body) as List<dynamic>;
        await _mergeLessons(remoteJson);
        debugPrint(
          '[LessonService] Synced ${remoteJson.length} lessons from remote.',
        );
      } else {
        debugPrint(
          '[LessonService] Remote sync failed: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[LessonService] Remote sync error: $e');
    }
  }

  /// Merges [lessonsJson] into the local box while preserving completion state.
  /// Removes lessons that are no longer present in the curriculum.
  Future<void> _mergeLessons(List<dynamic> lessonsJson) async {
    final incomingIds = <String>{};

    for (int i = 0; i < lessonsJson.length; i++) {
      final item = lessonsJson[i];
      if (item is! Map<String, dynamic>) continue;

      final incoming = Lesson.fromJson(item, i);
      incomingIds.add(incoming.id);

      Lesson? existing;
      try {
        existing = await _box.get(incoming.id);
      } catch (e) {
        debugPrint(
          '[LessonService] Schema mismatch reading lesson ${incoming.id}, healing key: $e',
        );
        await _box.delete(incoming.id);
      }

      if (existing != null) {
        incoming.completed = existing.completed;

        // Notification sync rules:
        if (incoming.notification == null || incoming.notification!.isEmpty) {
          // Notification was removed from the online file → blank it out and reset read.
          incoming.notification = null;
          incoming.read = false;
        } else if (incoming.notification != existing.notification) {
          // New or changed notification → mark as unread so the badge shows.
          incoming.read = false;
        } else {
          // Same notification text → keep the user's existing read state.
          incoming.read = existing.read;
        }
      }
      await _box.put(incoming.id, incoming);
    }

    // Prune stale lessons no longer in the curriculum.
    for (final key in List.of(_box.keys)) {
      if (key is String && !incomingIds.contains(key)) {
        await _box.delete(key);
      }
    }
  }

  /// Returns all lessons sorted by [Lesson.month], then [Lesson.order], and finally [Lesson.position].
  Future<List<Lesson>> getAllLessons() async {
    final lessons = <Lesson>[];
    for (final key in _box.keys) {
      try {
        final lesson = await _box.get(key);
        if (lesson != null) lessons.add(lesson);
      } catch (e) {
        debugPrint(
          '[LessonService] Schema mismatch reading lesson key $key, healing key: $e',
        );
        await _box.delete(key);
      }
    }
    lessons.sort((a, b) {
      final monthCmp = a.month.compareTo(b.month);
      if (monthCmp != 0) return monthCmp;
      final orderCmp = a.order.compareTo(b.order);
      if (orderCmp != 0) return orderCmp;
      return a.position.compareTo(b.position);
    });
    return lessons;
  }

  /// Persists the [completed] state for the lesson identified by [id].
  /// When [completed] becomes true, automatically resets [Lesson.read] to false
  /// so any attached notification surfaces as unread.
  Future<void> setCompleted(String id, {required bool completed}) async {
    final lesson = await _box.get(id);
    if (lesson != null) {
      lesson.completed = completed;
      if (completed) lesson.read = false; // surface notification as unread
      await _box.put(id, lesson);
    }
  }

  /// Marks the notification for [id] as read.
  Future<void> markNotificationRead(String id) async {
    final lesson = await _box.get(id);
    if (lesson != null && !lesson.read) {
      lesson.read = true;
      await _box.put(id, lesson);
    }
  }

  /// Returns all completed lessons that have an unread notification.
  Future<List<Lesson>> getUnreadNotifications() async {
    final lessons = await getAllLessons();
    return lessons
        .where(
          (l) =>
              l.completed && (l.notification?.isNotEmpty ?? false) && !l.read,
        )
        .toList();
  }

  // ── Daily Completion Tracking ──────────────────────────────────────────────

  Box get _settingsBox => Hive.box('settings');
  static const String _groupCompletionDatesKey = 'group_completion_dates';

  /// Returns a map of group keys to the date string (yyyy-MM-dd) they were completed.
  Map<String, String> getGroupCompletionDates() {
    final stored = _settingsBox.get(_groupCompletionDatesKey);
    if (stored == null) return {};
    return Map<String, String>.from(stored as Map);
  }

  /// Records or removes a group's completion date.
  Future<void> updateGroupCompletionDate(
    String groupKey,
    bool isCompleted,
  ) async {
    final Map<String, String> dates = getGroupCompletionDates();
    final todayStr = _getTodayDateString();

    if (isCompleted) {
      if (!dates.containsKey(groupKey)) {
        dates[groupKey] = todayStr;
        await _settingsBox.put(_groupCompletionDatesKey, dates);
        debugPrint(
          '[LessonService] Step group $groupKey completed on $todayStr',
        );
      }
    } else {
      if (dates.containsKey(groupKey)) {
        dates.remove(groupKey);
        await _settingsBox.put(_groupCompletionDatesKey, dates);
        debugPrint('[LessonService] Step group $groupKey completion removed');
      }
    }
  }

  /// Checks if any group was completed today.
  bool isDailyLessonCompletedToday() {
    final dates = getGroupCompletionDates();
    final todayStr = _getTodayDateString();
    return dates.values.contains(todayStr);
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }
}
