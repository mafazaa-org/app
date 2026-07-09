import 'package:flutter/material.dart';
import 'package:app/models/lesson.dart';
import 'package:app/services/lesson_service.dart';
import '../pages/notifications_modal.dart';

/// A bell icon button that shows a red badge when there are unread
/// notifications among the user's completed lessons.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => NotificationBellState();
}

// Made public so lessons.dart can call refresh() via GlobalKey.
class NotificationBellState extends State<NotificationBell> {
  final _service = LessonService();
  List<Lesson> _unread = [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final lessons = await _service.getAllLessons();
    final unread = lessons
        .where(
          (l) =>
              l.completed && (l.notification?.isNotEmpty ?? false) && !l.read,
        )
        .toList();
    if (mounted) setState(() => _unread = unread);
  }

  Future<void> _openModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationsModal(),
    );
    // Refresh badge after the modal is dismissed.
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 24,
          ),
          onPressed: _openModal,
          tooltip: 'الإشعارات',
        ),
        if (_unread.isNotEmpty)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
