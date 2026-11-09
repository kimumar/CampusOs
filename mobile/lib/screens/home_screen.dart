import 'package:flutter/material.dart';

import '../main.dart';
import '../services/course_storage.dart';
import '../services/lecture_storage.dart';
import 'courses_screen.dart';
import 'lecture_timetable_screen.dart';
import 'profile_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> {
  static const Color violet = Color(0xFF9463F5);
  static const Color mint = Color(0xFFA8F0D0);

  static const List<String> missions = [
    'Review yesterday\'s notes',
    'Practice 10 recall questions',
    'Complete a 25-minute study session',
  ];

  final Set<int> completed = {};

  int courseCount = 0;
  int totalUnits = 0;
  int lectureCount = 0;
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
    refreshSummary();
  }

  void refreshSummary() {
    if (!mounted) return;

    setState(() {
      courseCount = CourseStorage.courseCount;
      totalUnits = CourseStorage.totalUnits;
      lectureCount = LectureStorage.getLectures().length;
    });
  }

  Future<void> openScreen(Widget screen) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => screen));

    refreshSummary();
  }

  void comingSoon(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature is coming soon')));
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
                  comingSoon('Smart Recall');
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
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(pagePadding, 22, pagePadding, 32),
                children: [
                  buildHeader(),
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
        IconButton.filledTonal(
          tooltip: 'Appearance',
          onPressed: showAppearance,
          icon: const Icon(Icons.palette_outlined),
        ),
        const SizedBox(width: 5),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => comingSoon('Notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }

  Widget buildHero() {
    final progress = completed.length / missions.length;

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
                          const Text(
                            'Keep the\nmomentum.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              height: 1.13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${completed.length} of ${missions.length} preview missions',
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
                    onPressed: () => comingSoon('Quick Study'),
                    style: FilledButton.styleFrom(
                      backgroundColor: mint,
                      foregroundColor: const Color(0xFF202037),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start studying'),
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Preview only · Mission progress is not saved',
                  style: TextStyle(color: Color(0xFFEDE2FF), fontSize: 11),
                ),
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
                Icons.psychology_rounded,
                'Smart Recall',
                '—',
                'Coming soon',
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
    return Container(
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
    );
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
      (Icons.auto_stories_rounded, 'Smart Recall', 'Coming soon', 0),
      (Icons.note_alt_rounded, 'Lesson Notes', 'Coming soon', 0),
      (Icons.event_note_rounded, 'Study Planner', 'Coming soon', 0),
      (Icons.school_rounded, 'CGPA Simulator', 'Coming soon', 0),
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
    final progress = completed.length / missions.length;

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
            'A preview of your future study routine.',
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
              value: completed.contains(index),
              title: Text(
                missions[index],
                style: TextStyle(color: foreground, fontSize: 13),
              ),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    completed.add(index);
                  } else {
                    completed.remove(index);
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Preview only · Resets when the app restarts',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget buildPulse() {
    const periods = ['Today', 'This week', 'This month'];

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
            'Community progress, without exposing individuals.',
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
                      });
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
                        'Awaiting verified data',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Opt-in community statistics for ${periods[selectedPeriod].toLowerCase()} are not available yet.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          pulseRow('100% of goals reached'),
          pulseRow('At least 90% reached'),
          pulseRow('At least 50% reached'),
          Text(
            'No invented statistics or participation counts.',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget pulseRow(String label) {
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
            '—',
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
