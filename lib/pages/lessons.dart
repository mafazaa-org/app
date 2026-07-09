import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/lesson.dart';
import 'package:app/models/lesson_group.dart';
import 'package:app/services/lesson_service.dart';
import '../widgets/notification_bell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page entry point
// ─────────────────────────────────────────────────────────────────────────────

class LessonsPage extends StatefulWidget {
  const LessonsPage({super.key});

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  final _service = LessonService();
  final ScrollController _scrollController = ScrollController();

  List<LessonGroup> _groups = [];
  Lesson? _current;
  bool _loading = true;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  double _calculateScrollOffset(int targetIndex) {
    double offset = 0.0;
    for (int i = 0; i < targetIndex; i++) {
      final group = _groups[i];
      final groupHeaderHeight = 41.0;
      final lessonTilesHeight = group.lessons.length * 62.0;
      const cardMargin = 16.0;
      offset += groupHeaderHeight + lessonTilesHeight + cardMargin;
    }
    return offset;
  }

  Future<void> _loadLessons() async {
    try {
      final lessons = await _service.getAllLessons();
      final groups = LessonGroup.fromLessons(lessons);

      // Auto-select the first uncompleted lesson.
      final first = lessons.firstWhere(
        (l) => !l.completed,
        orElse: () => lessons.first,
      );

      setState(() {
        _groups = groups;
        _loading = false;
      });

      _selectLesson(first, autoPlay: false);

      // Scroll to the group containing the active lesson on startup.
      if (lessons.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final targetIndex = _groups.indexWhere(
              (g) => g.lessons.any((l) => l.id == _current?.id),
            );
            if (targetIndex > 0) {
              final offset = _calculateScrollOffset(targetIndex);
              _scrollController.animateTo(
                offset,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              );
            }
          }
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ── Player control ─────────────────────────────────────────────────────────

  void _selectLesson(Lesson lesson, {bool autoPlay = true}) {
    setState(() => _current = lesson);
  }

  Future<void> _toggleCompleted(Lesson lesson) async {
    setState(() => lesson.completed = !lesson.completed);
    await _service.setCompleted(lesson.id, completed: lesson.completed);

    // Find the group containing this lesson.
    final group = _groups.firstWhere(
      (g) => g.lessons.any((l) => l.id == lesson.id),
      orElse: () => LessonGroup(month: lesson.month, order: lesson.order, lessons: [lesson]),
    );
    final groupKey = '${group.month}_${group.order}';

    // Log the group completion date.
    await _service.updateGroupCompletionDate(groupKey, group.isCompleted);

    if (group.isCompleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            group.hasMultiple
                ? 'أحسنت! لقد أكملت هذه المجموعة من الدروس اليوم 🎉'
                : 'رائع! لقد أكملت هذا الدرس اليوم 🎉',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // After completing, refresh the notification bell so the badge updates immediately.
    _bellKey.currentState?.refresh();
  }

  Future<void> _launchCurrentVideo() async {
    if (_current == null) return;
    final url = Uri.parse(_current!.youtubeUrl);
    try {
      bool launched = false;
      try {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
      if (!launched) {
        launched = await launchUrl(url, mode: LaunchMode.platformDefault);
      }
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('عذرًا، لا يمكن فتح الرابط')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء تشغيل الفيديو: $e')),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  final GlobalKey<NotificationBellState> _bellKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final bell = NotificationBell(key: _bellKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('رحلة الدروس',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [bell],
      ),
      body: Stack(
        children: [
          _background(),
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _body(context),
        ],
      ),
    );
  }

  // ── Background decoration ──────────────────────────────────────────────────

  Widget _background() => Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.darkOne, AppColors.darkTwo],
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  // ── Main scrollable body ───────────────────────────────────────────────────

  Widget _body(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _playerCard(context),
          _sectionHeader('قائمة الدروس'),
          Expanded(
            child: _groupList(),
          ),
        ],
      );

  // ── Player card ────────────────────────────────────────────────────────────

  Widget _playerCard(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              if (_current != null && _current!.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    _current!.title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),

              // YouTube player or fallback placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildVideoContent(context),
                ),
              ),

              // Completion toggle + meta
              if (_current != null) _completionRow(_current!),
            ],
          ),
        ),
      );

  Widget _buildVideoContent(BuildContext context) {
    final thumbnailUrl = _current?.thumbnailUrl ?? '';
    return InkWell(
      onTap: _launchCurrentVideo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl.isNotEmpty)
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black54),
            )
          else
            Container(color: Colors.black54),
          Container(
            color: Colors.black.withValues(alpha: 0.6),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.play_circle_fill,
                color: AppColors.accent,
                size: 64,
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'شاهد الدرس على يوتيوب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'اضغط لتشغيل الفيديو في تطبيق يوتيوب أو المتصفح',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: AppColors.brightTwo.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _completionRow(Lesson lesson) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Toggle button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: lesson.completed
                    ? Colors.green.withValues(alpha: 0.15)
                    : AppColors.accent.withValues(alpha: 0.1),
                foregroundColor: lesson.completed ? Colors.greenAccent : AppColors.accent,
                side: BorderSide(
                  color: lesson.completed
                      ? Colors.greenAccent
                      : AppColors.accent.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () => _toggleCompleted(lesson),
              icon: Icon(
                lesson.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
              ),
              label: Text(
                lesson.completed ? 'تم الإكمال' : 'تحديد كمكتمل',
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            // Month / order meta
            Text(
              'الشهر ${lesson.month} • الدرس ${lesson.order}',
              style: TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.brightTwo.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(right: 24, left: 24, top: 12, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.right,
        ),
      );

  // ── Lesson groups list ─────────────────────────────────────────────────────

  Widget _groupList() => ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _groups.length,
        itemBuilder: (_, i) => _groupCard(_groups[i]),
      );

  Widget _groupCard(LessonGroup group) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: group.isCompleted
                  ? Colors.green.withValues(alpha: 0.25)
                  : AppColors.accent.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _groupHeader(group),
              const Divider(color: Colors.white10, height: 1, indent: 12, endIndent: 12),
              ...group.lessons.asMap().entries.map(
                    (e) => _lessonTile(e.value, e.key, group.hasMultiple),
                  ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );

  Widget _groupHeader(LessonGroup group) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Badges
            Wrap(
              spacing: 6,
              children: [
                if (group.hasMultiple)
                  _badge(
                    'درس ثنائي (${group.completedCount}/${group.lessons.length})',
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.accent,
                  ),
                if (group.isCompleted)
                  _badge('مكتمل ✓', Colors.green.withValues(alpha: 0.15), Colors.greenAccent),
              ],
            ),
            // Step label
            Text(
              'الشهر ${group.month} • الدرس ${group.order}',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.brightTwo,
              ),
            ),
          ],
        ),
      );

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 11,
            color: fg,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  // ── Single lesson tile ─────────────────────────────────────────────────────

  Widget _lessonTile(Lesson lesson, int idx, bool hasMultiple) {
    final isSelected = _current?.id == lesson.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => _selectLesson(lesson),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.white.withValues(alpha: 0.04),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Completion checkbox
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  lesson.completed ? Icons.check_box : Icons.check_box_outline_blank,
                  color: lesson.completed
                      ? AppColors.accent
                      : AppColors.brightTwo.withValues(alpha: 0.4),
                  size: 20,
                ),
                onPressed: () => _toggleCompleted(lesson),
              ),
              const SizedBox(width: 6),
              // Play indicator
              Icon(
                isSelected ? Icons.play_circle_fill : Icons.play_circle_outline,
                color: isSelected
                    ? AppColors.accent
                    : AppColors.brightTwo.withValues(alpha: 0.6),
                size: 18,
              ),
              const SizedBox(width: 10),
              // Title + part label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lesson.title.isNotEmpty ? lesson.title : 'بدون عنوان',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppColors.brightOne,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    if (hasMultiple)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          'المادة رقم ${idx + 1}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.brightTwo.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 70,
                  height: 39,
                  child: lesson.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          lesson.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() => Container(
        color: Colors.black26,
        child: const Icon(Icons.video_library, color: Colors.white24, size: 18),
      );
}
