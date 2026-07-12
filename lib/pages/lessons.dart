import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/lesson.dart';
import 'package:app/models/lesson_group.dart';
import 'package:app/services/lesson_access_policy.dart';
import 'package:app/services/lesson_service.dart';
import 'package:app/widgets/embedded_youtube_player.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int? _selectedMonth;

  List<Lesson> _lessons = [];
  List<LessonGroup> _groups = [];
  Lesson? _current;
  final Set<String> _completionUpdates = {};
  bool _loading = true;
  String? _loadError;

  // ── Platform Compatibility check ───────────────────────────────────────────

  bool get _supportsEmbeddedPlayer {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

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

  List<int> get _months {
    final values = _groups.map((group) => group.month).toSet().toList()..sort();
    return values;
  }

  List<LessonGroup> get _visibleGroups {
    final month = _selectedMonth;
    if (month == null) return _groups;

    return _groups.where((group) => group.month == month).toList();
  }

 

  Future<void> _loadLessons() async {
    try {
      final lessons = await _service.getAllLessons();
      final groups = LessonGroup.fromLessons(lessons);

      final current = LessonAccessPolicy.currentLesson(lessons);
      if (!mounted) return;

      setState(() {
        _lessons = lessons;
        _groups = groups;
        _current = current;
        _selectedMonth =
            current?.month ?? (lessons.isNotEmpty ? lessons.first.month : null);
        _loading = false;
        _loadError = lessons.isEmpty ? 'لا توجد دروس متاحة حاليًا.' : null;
      });
      // Scroll to the group containing the active lesson on startup.
      if (current != null) {
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'تعذر تحميل الدروس. تحقق من الاتصال وحاول مرة أخرى.';
      });
    }
  }

  // ── Player control ─────────────────────────────────────────────────────────

  Future<void> _toggleCompleted(Lesson lesson) async {
    if (_completionUpdates.contains(lesson.id)) return;

    final blocker = LessonAccessPolicy.blockingLesson(_lessons, lesson);
    if (!lesson.completed && blocker != null) {
      _showLockedLessonMessage(blocker);
      return;
    }

    final previousValue = lesson.completed;
    final nextValue = !previousValue;

    setState(() => _completionUpdates.add(lesson.id));

    try {
      final saved = await _service.setCompleted(
        lesson.id,
        completed: nextValue,
      );

      if (saved == null) {
        throw StateError('Lesson ${lesson.id} was not found in local storage.');
      }

      if (!mounted) return;

      setState(() {
        lesson.completed = saved.completed;

        final selected = _current;
        if (!saved.completed &&
            selected != null &&
            !LessonAccessPolicy.isUnlocked(_lessons, selected)) {
          _current = lesson;
        }
      });

      final group = _groups.firstWhere(
        (group) => group.lessons.any((item) => item.id == lesson.id),
        orElse: () => LessonGroup(
          month: lesson.month,
          order: lesson.order,
          lessons: [lesson],
        ),
      );

      final groupKey = '${group.month}_${group.order}';
      await _service.updateGroupCompletionDate(groupKey, group.isCompleted);

      if (group.isCompleted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              group.hasMultiple
                  ? 'أحسنت! لقد أكملت هذه المجموعة من الدروس اليوم 🎉'
                  : 'رائع! لقد أكملت هذا الدرس اليوم 🎉',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      _bellKey.currentState?.refresh();
    } catch (error) {
      lesson.completed = previousValue;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر حفظ حالة الدرس. حاول مرة أخرى.',
            textAlign: TextAlign.right,
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _completionUpdates.remove(lesson.id));
      }
    }
  }

  bool _isLessonUnlocked(Lesson lesson) {
    return LessonAccessPolicy.isUnlocked(_lessons, lesson);
  }

  void _selectLesson(Lesson lesson) {
    final blocker = LessonAccessPolicy.blockingLesson(_lessons, lesson);
    if (blocker != null) {
      _showLockedLessonMessage(blocker);
      return;
    }

    setState(() => _current = lesson);
  }

  void _showLockedLessonMessage(Lesson blocker) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'أكمل الدرس السابق أولًا:\n${blocker.title}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  final GlobalKey<NotificationBellState> _bellKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final bell = NotificationBell(key: _bellKey);

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _monthsDrawer(),
      appBar: AppBar(
        title: const Text(
          'رحلة الدروس',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'اختيار الشهر',
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          bell,
        ],
      ),
      body: Stack(
        children: [
          _background(),
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                )
              : _loadError != null
              ? _errorState(_loadError!)
              : _body(),
        ],
      ),
    );
  }

  Widget _monthsDrawer() {
    final months = _months;

    return Drawer(
      backgroundColor: AppColors.darkTwo,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'الشهور',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: ListView.builder(
                itemCount: months.length,
                itemBuilder: (_, index) {
                  final month = months[index];
                  final selected = month == _selectedMonth;
                  final groups = _groups.where((group) => group.month == month);
                  final totalLessons = groups.fold<int>(
                    0,
                    (sum, group) => sum + group.lessons.length,
                  );
                  final completedLessons = groups.fold<int>(
                    0,
                    (sum, group) =>
                        sum +
                        group.lessons
                            .where((lesson) => lesson.completed)
                            .length,
                  );

                  return ListTile(
                    selected: selected,
                    selectedTileColor: AppColors.accent.withValues(alpha: 0.12),
                    trailing: Icon(
                      selected ? Icons.folder_open : Icons.folder_outlined,
                      color: selected ? AppColors.accent : Colors.white70,
                    ),
                    title: Text(
                      'الشهر $month',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: selected ? AppColors.accent : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '$completedLessons / $totalLessons مكتمل',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      setState(() => _selectedMonth = month);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Cairo',
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ),
  );

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

  Widget _body() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _playerCard(),
      _sectionHeader(
        _selectedMonth == null ? 'قائمة الدروس' : 'دروس الشهر $_selectedMonth',
      ),
      Expanded(child: _groupList()),
    ],
  );

  // ── Player card ────────────────────────────────────────────────────────────

  Widget _playerCard() => Padding(
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
                _current!.displayTitle,
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
              child: _buildVideoContent(),
            ),
          ),

          // Completion toggle + meta
          if (_current != null) _completionRow(_current!),
        ],
      ),
    ),
  );

  Widget _buildVideoContent() {
    final current = _current;
    if (current == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'اختر درسًا للبدء',
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (_supportsEmbeddedPlayer) {
      return EmbeddedYoutubePlayer(
        key: ValueKey(
          '${current.id}_${current.startSecond}_${current.endSecond}',
        ),
        videoUrl: current.youtubeUrl,
        startSecond: current.startSecond,
        endSecond: current.endSecond,
      );
    }

    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'المشغل المدمج متاح حاليًا على Android وiOS.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _completionRow(Lesson lesson) {
    final isUpdating = _completionUpdates.contains(lesson.id);
    final isUnlocked = _isLessonUnlocked(lesson);
    final accentColor = lesson.completed
        ? Colors.greenAccent
        : isUnlocked
        ? AppColors.accent
        : AppColors.brightTwo.withValues(alpha: 0.35);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor.withValues(alpha: 0.12),
              foregroundColor: accentColor,
              disabledBackgroundColor: accentColor.withValues(alpha: 0.08),
              disabledForegroundColor: accentColor,
              side: BorderSide(color: accentColor.withValues(alpha: 0.55)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: isUpdating ? null : () => _toggleCompleted(lesson),
            icon: isUpdating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  )
                : Icon(
                    !isUnlocked && !lesson.completed
                        ? Icons.lock_outline
                        : lesson.completed
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                  ),
            label: Text(
              !isUnlocked && !lesson.completed
                  ? 'أكمل السابق أولًا'
                  : lesson.completed
                  ? 'تم الإكمال'
                  : 'اكتمل بعد مشاهدة أكثر من النصف',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
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
  }

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

  Widget _groupList() {
    final groups = _visibleGroups;

    if (groups.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد دروس في هذا الشهر.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: groups.length,
      itemBuilder: (_, i) => _groupCard(groups[i]),
    );
  }

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
          const Divider(
            color: Colors.white10,
            height: 1,
            indent: 12,
            endIndent: 12,
          ),
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
              _badge(
                'مكتمل ✓',
                Colors.green.withValues(alpha: 0.15),
                Colors.greenAccent,
              ),
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
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
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
    final isUnlocked = _isLessonUnlocked(lesson);
    final isUpdating = _completionUpdates.contains(lesson.id);
    final mutedColor = AppColors.brightTwo.withValues(alpha: 0.32);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        onTap: () => _selectLesson(lesson),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : !isUnlocked
                ? Colors.black.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.04),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Completion checkbox
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : Icon(
                        !isUnlocked && !lesson.completed
                            ? Icons.lock_outline
                            : lesson.completed
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: lesson.completed
                            ? AppColors.accent
                            : isUnlocked
                            ? AppColors.brightTwo.withValues(alpha: 0.5)
                            : mutedColor,
                        size: 20,
                      ),
                onPressed: isUpdating ? null : () => _toggleCompleted(lesson),
              ),
              const SizedBox(width: 6),
              // Play indicator
              Icon(
                !isUnlocked
                    ? Icons.lock
                    : isSelected
                    ? Icons.play_circle_fill
                    : Icons.play_circle_outline,
                color: isSelected
                    ? AppColors.accent
                    : isUnlocked
                    ? AppColors.brightTwo.withValues(alpha: 0.6)
                    : mutedColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              // Title + part label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      lesson.displayTitle.isNotEmpty
                          ? lesson.displayTitle
                          : 'بدون عنوان',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : isUnlocked
                            ? AppColors.brightOne
                            : mutedColor,
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
                                : isUnlocked
                                ? AppColors.brightTwo.withValues(alpha: 0.6)
                                : mutedColor,
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      lesson.thumbnailUrl.isNotEmpty
                          ? Image.network(
                              lesson.thumbnailUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _thumbPlaceholder(),
                            )
                          : _thumbPlaceholder(),
                      if (!isUnlocked)
                        ColoredBox(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
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
