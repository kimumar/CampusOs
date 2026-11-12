import 'package:flutter/material.dart';

import '../main.dart';
import '../services/course_storage.dart';
import '../services/lecture_storage.dart';
import '../services/study_mission_storage.dart';
import '../services/check_in_storage.dart';
import '../services/academic_task_storage.dart';
import '../services/profile_storage.dart';
import '../services/academic_notifications.dart';
import '../services/auth_api.dart';
import '../services/cloud_sync.dart';
import '../services/community_pulse.dart';
import 'dart:async';
import 'focus_study_screen.dart';
import 'courses_screen.dart';
import 'lecture_timetable_screen.dart';
import 'profile_screen.dart';
import 'recall_history_screen.dart';
import 'academic_planner_screen.dart';
import 'academic_report_screen.dart';
import 'cgpa_simulator_screen.dart';
import 'smart_notes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.appearance,
    required this.onAppearanceChanged,
    required this.onLogout,
  });

  final CampusAppearance appearance;
  final ValueChanged<CampusAppearance> onAppearanceChanged;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Color violet = Color(0xFF9463F5);
  static const Color mint = Color(0xFFA8F0D0);

  List<Map<String, dynamic>> missions = [];
  int studyStreak = 0;
  Timer? _dayRefresh;
  Timer? _midnightRefresh;
  CommunityPulse? _communityPulse;
  bool _pulseLoading = false;
  String? _pulseNotice;

  Future<void> refreshCommunityPulse() async {
    if (_pulseLoading || AuthApi.account == null) {
      return;
    }
    setState(() { _pulseLoading = true; _pulseNotice = null; _communityPulse = null; });
    try {
      await CloudSync.synchronize();
      final periods = ['today', 'week', 'month'];
      final response = await AuthApi.communityPulse(periods[selectedPeriod]);
      if (mounted) {
        setState(() => _communityPulse = response);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pulseNotice =
          'Community results are temporarily unavailable. Your saved progress is safe and will sync when connected.');
      }
    } finally {
      if (mounted) {
        setState(() => _pulseLoading = false);
      }
    }
  }

  Future<void> refreshMissions() async {
    await CheckInStorage.recordCheckIn();
    final records = await StudyMissionStorage.ensureToday();
    if (!mounted) return;
    setState(() {
      missions = records;
      studyStreak = CheckInStorage.streak();
      deadlinesThisWeek = _countDeadlines();
    });
    CloudSync.queueSync();
    AcademicNotifications.reschedule();
  }

  int _countDeadlines() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    // Include the seventh calendar day (e.g., Nov 18 when today is Nov 11).
    final end = start.add(const Duration(days: 8));
    return AcademicTaskStorage.all(includeDone: false).where((task) {
      final due = DateTime.tryParse((task['due_at'] ?? '').toString())?.toLocal();
      return due != null && !due.isBefore(start) && due.isBefore(end);
    }).length;
  }

  void showTodayProgress() {
    final finished = missions.where((mission) => mission['done'] == true).length;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final tomorrowPriorities = StudyMissionStorage.suggestionsFor(tomorrow);
    showModalBottomSheet<void>(context: context, showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
        child: ListView(shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
            Text('Today’s progress', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$finished of ${missions.length} missions completed'),
            const SizedBox(height: 12),
            for (final mission in missions)
              ListTile(
                leading: Icon(mission['done'] == true ? Icons.check_circle : Icons.radio_button_unchecked),
                title: Text((mission['title'] ?? '').toString()),
                subtitle: Text(mission['done'] == true ? 'Completed' : 'Available whenever you are ready'),
              ),
            const SizedBox(height: 12),
            Text('Tomorrow preview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            const Text('A provisional preview; the actual plan refreshes at the next local midnight.'),
            if (tomorrowPriorities.isEmpty)
              const ListTile(title: Text('No urgent academic priorities recorded for tomorrow.')),
            for (final mission in tomorrowPriorities.take(3))
              ListTile(dense: true, leading: const Icon(Icons.arrow_forward_rounded),
                title: Text((mission['title'] ?? '').toString())),
            const SizedBox(height: 14),
            FilledButton(onPressed: () => Navigator.of(sheetContext).pop(), child: const Text('Done')),
          ],
        ),
      )),
    );
  }

  void showStreakDetails() {
    final today = DateTime.now();
    final days = CheckInStorage.days();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8),
          child: ListView(shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              const Text('Your check-in streak', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('$studyStreak check-in ${studyStreak == 1 ? 'day' : 'days'} in your current run'),
              const SizedBox(height: 6),
              Text(CheckInStorage.checkedInToday() ? 'You checked in today.' : 'Open CampusOS to check in. No study session required.'),
              const SizedBox(height: 14),
              const Text('Last 7 days · a tick means a check-in, not mastery'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var offset = 6; offset >= 0; offset--)
                  Builder(builder: (context) {
                    final day = DateTime(today.year, today.month, today.day - offset);
                    final earned = days.contains(CheckInStorage.dayKey(day));
                    return Chip(
                      avatar: Icon(earned ? Icons.check_circle : Icons.circle_outlined,
                        size: 17, color: earned ? const Color(0xFF5CC9A8) : null),
                      label: Text('${day.day}/${day.month}'),
                    );
                  }),
              ]),
              const SizedBox(height: 12),
              const Text('Checking in keeps your consistency streak. Academic learning and mastery are measured separately. One grace day can bridge a missed check-in without adding a fictional day.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  openStudy();
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Study if you want'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> toggleMission(int index, bool value) async {
    await StudyMissionStorage.setCompleted(missions[index]['id'] as String, value);
    await refreshMissions();
    await refreshCommunityPulse();
  }

  Future<void> openStudy() async {
    await refreshMissions();
    if (!mounted) return;
    final courses = CourseStorage.getCourses();
    final studyTasks = missions.where((m) => m['kind'] == 'study' && m['done'] != true).toList();
    final courseId = studyTasks.isNotEmpty ? (studyTasks.first['course_id'] ?? '').toString()
        : (courses.isNotEmpty ? courses.first.id : '');
    final chosen = courses.where((course) => course.id == courseId);
    final course = chosen.isNotEmpty ? chosen.first : null;
    final task = studyTasks.isNotEmpty ? studyTasks.first : null;
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => FocusStudyScreen(
        missionId: task?['id']?.toString() ?? 'independent::${StudyMissionStorage.dayKey()}',
        title: course?.title ?? 'Independent study',
        courseId: courseId,
      ),
    ));
    if (mounted) await refreshMissions();
  }

  Future<void> openMission(Map<String, dynamic> mission) async {
    final kind = (mission['kind'] ?? 'study').toString();
    if (kind == 'recall' || kind == 'due') {
      await openScreen(const RecallHistoryScreen());
    } else if (kind == 'task') {
      await openScreen(const AcademicPlannerScreen());
    } else {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => FocusStudyScreen(
          missionId: (mission['id'] ?? '').toString(),
          title: (mission['course_name'] ?? '').toString(),
          courseId: (mission['course_id'] ?? '').toString(),
        ),
      ));
      if (mounted) await refreshMissions();
    }
  }

  void _scheduleMidnight() {
    _midnightRefresh?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnightRefresh = Timer(midnight.difference(now) + const Duration(milliseconds: 150), () async {
      if (!mounted) return;
      await refreshMissions();
      _scheduleMidnight();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshMissions();
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayRefresh?.cancel();
    _midnightRefresh?.cancel();
    super.dispose();
  }

  int courseCount = 0;
  int totalUnits = 0;
  int lectureCount = 0;
  int deadlinesThisWeek = 0;
  int selectedPeriod = 0;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get foreground => Theme.of(context).colorScheme.onSurface;

  Color get muted => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get accent => Theme.of(context).colorScheme.primary;

  Color get panel => isDark ? const Color(0xFF242239) : Colors.white;

  Color get subtle =>
      isDark ? const Color(0xFF34304A) : const Color(0xFFF0EDFA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshSummary();
    refreshMissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) refreshCommunityPulse();
    });
    _scheduleMidnight();
    // Missions are refreshed on actual changes, resume and at midnight.
    // Re-reading all Hive stores every minute wastes battery on offline phones.
  }

  void refreshSummary() {
    if (!mounted) return;

    setState(() {
      courseCount = CourseStorage.courseCount;
      totalUnits = CourseStorage.totalUnits;
      lectureCount = LectureStorage.getLectures().length;
      deadlinesThisWeek = _countDeadlines();
    });
  }

  Future<void> openScreen(Widget screen) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => screen));

    if (!mounted) return;
    refreshSummary();
    await refreshMissions();
  }

  void comingSoon(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature is coming soon')));
  }

  Future<void> _showNotifications() async {
    if (!AcademicNotifications.enabled || !await AcademicNotifications.permissionGranted()) {
      if (!mounted) return;
      final enable = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Stay on track 💜'),
        content: const Text('Would you like gentle reminders for lectures, deadlines and your study plan? You can turn them off anytime in Profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Enable reminders')),
        ],
      ));
      if (enable != true) return;
      await AcademicNotifications.setEnabled(true);
      if (!mounted) return;
      if (!await AcademicNotifications.permissionGranted()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please allow CampusOS notifications in your phone settings.')));
        return;
      }
    }
    final recent = await AcademicNotifications.recentDelivered();
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true,
      isScrollControlled: true, builder: (sheetContext) => SafeArea(child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * .8),
        child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 24), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Recent notifications', style: Theme.of(sheetContext).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('Your last 3 delivered reminders on this device.'),
          const SizedBox(height: 14),
          if (recent.isEmpty) const ListTile(leading: Icon(Icons.notifications_none_rounded),
            title: Text('No notifications yet'), subtitle: Text('New reminders will appear here once delivered.')),
          for (final item in recent.take(3)) ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text((item['title'] ?? 'CampusOS reminder').toString()),
            subtitle: Text((item['body'] ?? '').toString()),
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Done'))),
        ])),
      )));
  }

  void showAppearance() {
    final options = <(CampusAppearance, IconData, String)>[
      (CampusAppearance.system, Icons.brightness_auto_rounded, 'Follow device'),
      (CampusAppearance.light, Icons.light_mode_rounded, 'Light'),
      (CampusAppearance.dark, Icons.dark_mode_rounded, 'Dark'),
      (
        CampusAppearance.nightComfort,
        Icons.nights_stay_rounded,
        'Night Comfort',
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (option) => ListTile(
                    leading: Icon(option.$2, color: accent),
                    title: Text(option.$3),
                    trailing: widget.appearance == option.$1
                        ? Icon(Icons.check_circle_rounded, color: accent)
                        : null,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      widget.onAppearanceChanged(option.$1);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 760;

    final pagePadding = width < 360
        ? 14.0
        : wide
        ? 28.0
        : 18.0;

    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  label: 'Courses',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Timetable',
                ),
                NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  label: 'Recall',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  label: 'Profile',
                ),
              ],
              onDestinationSelected: (index) {
                if (index == 1) {
                  openScreen(const CoursesScreen());
                } else if (index == 2) {
                  openScreen(const LectureTimetableScreen());
                } else if (index == 3) {
                  openScreen(const RecallHistoryScreen());
                } else if (index == 4) {
                  openScreen(ProfileScreen(
                    appearance: widget.appearance,
                    onAppearanceChanged: widget.onAppearanceChanged,
                    onLogout: widget.onLogout,
                  ));
                }
              },
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: RefreshIndicator(
              onRefresh: () async {
                refreshSummary();
                await refreshMissions();
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(pagePadding, 22, pagePadding, 32),
                children: [
                  buildHeader(),
                  const SizedBox(height: 18),
                  buildAcademicAssistant(),
                  const SizedBox(height: 27),
                  Text(
                    'Your academic space',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: width < 360 ? 26 : 30,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Don\'t just read. Remember what you study.',
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                  const SizedBox(height: 23),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: buildHero()),
                        const SizedBox(width: 18),
                        Expanded(flex: 5, child: buildStats()),
                      ],
                    )
                  else ...[
                    buildHero(),
                    const SizedBox(height: 17),
                    buildStats(),
                  ],
                  const SizedBox(height: 28),
                  sectionHeading(
                    'Your academic toolkit',
                    'Everything in one place',
                  ),
                  const SizedBox(height: 14),
                  buildToolkit(wide),
                  const SizedBox(height: 28),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: buildMissions()),
                        const SizedBox(width: 18),
                        Expanded(child: buildPulse()),
                      ],
                    )
                  else ...[
                    buildMissions(),
                    const SizedBox(height: 18),
                    buildPulse(),
                  ],
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    return Row(
      children: [
        Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [violet, Color(0xFF6C55E8)]),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(padding: const EdgeInsets.all(4), child: Image.asset('assets/branding/campusos_icon_transparent.png',fit:BoxFit.contain)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CampusOS',
                style: TextStyle(
                  color: foreground,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Your study companion',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Your check-in streak — tap for the last 7 days',
          child: InkWell(
            onTap: showStreakDetails,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: Color(0xFFFFB74D), size: 23),
                const SizedBox(width: 2),
                Text('$studyStreak', style: TextStyle(
                  color: foreground, fontSize: 17, fontWeight: FontWeight.w900,
                )),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'Appearance',
          onPressed: showAppearance,
          icon: const Icon(Icons.palette_outlined),
        ),
        const SizedBox(width: 5),
        IconButton(
          tooltip: 'Notifications',
          onPressed: _showNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }

  Widget buildAcademicAssistant() {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final profile = ProfileStorage.load();
    final name = profile.name.trim().isEmpty ? 'scholar' : profile.name.trim().split(' ').first;
    final todaysLectures = LectureStorage.getLectures().where((lecture) => lecture.day == now.weekday).length;
    final today = DateTime(now.year, now.month, now.day);
    final pending = AcademicTaskStorage.all(includeDone: false);
    final upcoming = pending.where((task) {
      final date = DateTime.tryParse((task['due_at'] ?? '').toString())?.toLocal();
      return date != null && !date.isBefore(today);
    }).toList();
    final nextDue = upcoming.isEmpty ? null : DateTime.tryParse((upcoming.first['due_at'] ?? '').toString())?.toLocal();
    final daysAway = nextDue == null ? null : DateTime(nextDue.year, nextDue.month, nextDue.day).difference(today).inDays;
    final unfinished = missions.where((mission) => mission['done'] != true).length;
    // The app never claims to have rescheduled a missed mission unless that
    // rescheduling has actually been persisted by the mission engine.
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.auto_awesome_rounded, color: accent), const SizedBox(width: 8),
          Expanded(child: Text('$greeting, $name! 💜',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)))]),
        const SizedBox(height: 8),
        Text('Here is your academic day at a glance.', style: TextStyle(color: muted)),
        const SizedBox(height: 14),
        _assistantLine(Icons.school_outlined, '$todaysLectures ${todaysLectures == 1 ? 'lecture' : 'lectures'} scheduled today'),
        _assistantLine(Icons.event_note_outlined, daysAway == null
          ? 'No upcoming academic deadlines recorded'
          : '${upcoming.length} upcoming deadline${upcoming.length == 1 ? '' : 's'} · next ${daysAway == 0 ? 'due today' : 'in $daysAway day${daysAway == 1 ? '' : 's'}'}'),
        _assistantLine(Icons.track_changes_outlined, '$unfinished study mission${unfinished == 1 ? '' : 's'} remaining today'),
        const SizedBox(height: 6),
        Text('Missed a study session? Your next Daily Mission helps you pick up gently. No streak punishment.',
          style: TextStyle(color: muted, fontSize: 12)),
      ]),
    );
  }

  Widget _assistantLine(IconData icon, String message) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 19, color: accent), const SizedBox(width: 10),
      Expanded(child: Text(message, style: TextStyle(color: foreground))),
    ]),
  );

  Widget buildHero() {
    final progress = missions.isEmpty ? 0.0 : missions.where((m) => m['done'] == true).length / missions.length;
    final completed = missions.isNotEmpty && progress >= 1.0;
    final inProgress = progress > 0 && !completed;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFAE79F4), Color(0xFF8049DE), Color(0xFF5930B3)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -55,
            top: -75,
            child: Container(
              width: 195,
              height: 195,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            left: -35,
            bottom: -95,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'MY STUDY PLAN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 21),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            completed ? 'Today’s goals\nachieved!' : inProgress ? 'Keep the\nmomentum.' : 'Ready for\ntoday?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              height: 1.13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${missions.where((m) => m['done'] == true).length} of ${missions.length} missions completed',
                            style: const TextStyle(
                              color: Color(0xFFF0E8FF),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 86,
                      height: 86,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 9,
                              strokeCap: StrokeCap.round,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.25,
                              ),
                              color: mint,
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 21),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: openStudy,
                    style: FilledButton.styleFrom(
                      backgroundColor: mint,
                      foregroundColor: const Color(0xFF202037),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(completed ? 'Study something else' : inProgress ? 'Continue studying' : 'Start studying'),
                  ),
                ),
                if (completed) ...[
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: showTodayProgress,
                      icon: const Icon(Icons.assessment_outlined),
                      label: const Text('View today’s progress'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;

        final tileWidth = (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: tileWidth,
              child: buildStat(
                Icons.menu_book_rounded,
                'Courses',
                '$courseCount',
                'Registered',
                const Color(0xFFAF8BFF),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: buildStat(
                Icons.school_rounded,
                'Credit units',
                '$totalUnits',
                'This semester',
                const Color(0xFFFFD27B),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: buildStat(
                Icons.calendar_month_rounded,
                'Lectures',
                '$lectureCount',
                'Weekly schedule',
                const Color(0xFFA8F0D0),
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: buildStat(
                Icons.event_note_rounded,
                'Deadlines',
                '$deadlinesThisWeek',
                'Due this week',
                const Color(0xFFFF9EAC),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildStat(
    IconData icon,
    String label,
    String value,
    String caption,
    Color highlight,
  ) {
    return InkWell(
      onTap: label == 'Deadlines' ? () => openScreen(const AcademicPlannerScreen()) : null,
      borderRadius: BorderRadius.circular(21),
      child: Container(
      constraints: const BoxConstraints(minHeight: 146),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: accent.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: highlight.withValues(alpha: isDark ? 0.16 : 0.20),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: isDark ? highlight : accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            style: TextStyle(color: muted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ));
  }

  Widget sectionHeading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: muted, fontSize: 13)),
      ],
    );
  }

  Widget buildToolkit(bool wide) {
    final tools = <(IconData, String, String, int)>[
      (
        Icons.library_books_rounded,
        'My Courses',
        'Manage registered courses',
        1,
      ),
      (
        Icons.calendar_month_rounded,
        'Lecture Timetable',
        'Your weekly schedule',
        2,
      ),
      (Icons.auto_stories_rounded, 'Smart Recall', 'Recall & revision', 3),
      (Icons.note_alt_rounded, 'Smart Notes', 'Text & photo study', 4),
      (Icons.event_note_rounded, 'Study Planner', 'Tasks & deadlines', 5),
      (Icons.school_rounded, 'CGPA Simulator', 'Grade scenarios', 6),
      (Icons.insights_rounded, 'Weekly Report', 'Learning insights', 7),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = wide ? 3 : 2;
        const gap = 11.0;

        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tools.map((tool) {
            return SizedBox(
              width: tileWidth,
              child: Material(
                color: panel,
                borderRadius: BorderRadius.circular(19),
                child: InkWell(
                  borderRadius: BorderRadius.circular(19),
                  onTap: () {
                    if (tool.$4 == 1) {
                      openScreen(const CoursesScreen());
                    } else if (tool.$4 == 2) {
                      openScreen(const LectureTimetableScreen());
                    } else if (tool.$4 == 3) {
                      openScreen(const RecallHistoryScreen());
                    } else if (tool.$4 == 4) {
                      openScreen(const SmartNotesScreen());
                    } else if (tool.$4 == 5) {
                      openScreen(const AcademicPlannerScreen());
                    } else if (tool.$4 == 6) {
                      openScreen(const CgpaSimulatorScreen());
                    } else if (tool.$4 == 7) {
                      openScreen(const AcademicReportScreen());
                    } else {
                      comingSoon(tool.$2);
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 123),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 37,
                          height: 37,
                          decoration: BoxDecoration(
                            color: subtle,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(tool.$1, size: 21, color: accent),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tool.$2,
                          style: TextStyle(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tool.$3,
                          style: TextStyle(color: muted, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget buildMissions() {
    final progress = missions.isEmpty ? 0.0 : missions.where((m) => m['done'] == true).length / missions.length;

    return panelBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Daily missions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(color: accent, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Small actions based on your courses, deadlines and revision.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            color: accent,
            backgroundColor: subtle,
          ),
          const SizedBox(height: 13),
          ...List.generate(
            missions.length,
            (index) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: missions[index]['done'] == true,
              title: Text(
                missions[index]['title'] as String,
                style: TextStyle(color: foreground, fontSize: 13),
              ),
              secondary: IconButton(
                tooltip: 'Open mission',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => openMission(missions[index]),
              ),
              onChanged: (checked) => toggleMission(index, checked == true),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            missions.isEmpty ? 'Add a course or deadline to see personal priorities.' : 'Saved on this device · No forced timer or penalty for missed work',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget buildPulse() {
    const periods = ['Today', 'This week', 'This month'];
    final snapshot = _communityPulse;

    return panelBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph_rounded, color: accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Campus Pulse',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'See how CampusOS students are progressing together. Results are anonymous; no names or student counts.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 15),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                periods.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(periods[index]),
                    selected: selectedPeriod == index,
                    onSelected: (_) {
                      setState(() {
                        selectedPeriod = index;
                        _communityPulse = null;
                      });
                      refreshCommunityPulse();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: subtle,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(Icons.groups_outlined, color: accent, size: 27),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot != null ? 'Community achievement' : 'Awaiting verified community statistics',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        snapshot != null
                          ? 'Updated ${snapshot.asOf.toLocal().toString().split('.').first}'
                          : (_pulseNotice ?? 'Connect to the internet to see community progress for ${periods[selectedPeriod].toLowerCase()}.'),
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          pulseRow('Completed all planned goals', snapshot == null ? '—' : '${snapshot.percent100}%'),
          pulseRow('Reached 90% or more', snapshot == null ? '—' : '${snapshot.percent90}%'),
          pulseRow('Reached 50% or more', snapshot == null ? '—' : '${snapshot.percent50}%'),
          TextButton.icon(onPressed: _pulseLoading ? null : refreshCommunityPulse,
            icon: const Icon(Icons.refresh), label: Text(_pulseLoading ? 'Updating…' : 'Refresh Campus Pulse')),
          Text(
            'Includes students with active access. Your offline progress will count after it syncs.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget pulseRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: foreground, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: muted, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget panelBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
