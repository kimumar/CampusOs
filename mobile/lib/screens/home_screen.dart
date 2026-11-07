import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import 'courses_screen.dart';
import 'lecture_timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.appearance,
    required this.onAppearanceChanged,
  });

  final CampusAppearance appearance;
  final ValueChanged<CampusAppearance> onAppearanceChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  final List<String> _missions = [
    'Review yesterday\'s notes',
    'Practice 10 recall questions',
    'Complete a 25-minute study session',
  ];

  final Set<int> _completed = {};
  int _period = 0;

  double get _progress => _completed.length / _missions.length;
  Color get _ink => Theme.of(context).colorScheme.onSurface;
  Color get _muted =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _accent => Theme.of(context).colorScheme.primary;
  Color get _surface => Theme.of(context).colorScheme.surface;
  bool get _dark =>
      Theme.of(context).brightness == Brightness.dark;
  Color get _soft => _dark
      ? const Color(0xFF3B3749)
      : const Color(0xFFF3F1FA);

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature is coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _appearanceSheet() {
    final options = [
      (
        CampusAppearance.system,
        Icons.brightness_auto_rounded,
        'Follow device',
      ),
      (
        CampusAppearance.light,
        Icons.light_mode_rounded,
        'Light',
      ),
      (
        CampusAppearance.dark,
        Icons.dark_mode_rounded,
        'Dark',
      ),
      (
        CampusAppearance.nightComfort,
        Icons.nights_stay_rounded,
        'Night Comfort',
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium,
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (option) => ListTile(
                    leading: Icon(option.$2, color: _accent),
                    title: Text(option.$3),
                    trailing: widget.appearance == option.$1
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: _accent,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext);
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

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: _dark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFEFEAF8),
        ),
      ),
      child: child,
    );
  }

  Widget _heading(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _ink,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            label: 'Recall',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) return;
          const names = [
            'Home',
            'Smart Recall',
            'Study Planner',
            'Profile',
          ];
          _comingSoon(names[index]);
        },
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: tablet ? 32 : 18,
                vertical: 22,
              ),
              children: [
                _header(),
                const SizedBox(height: 27),
                Text(
                  'Make today count.',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 31,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Small steps. Stronger results.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 23),
                _hero(),
                const SizedBox(height: 21),
                if (tablet)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _dailyMissions(),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 2,
                        child: _momentum(),
                      ),
                    ],
                  )
                else
                  _dailyMissions(),
                const SizedBox(height: 20),
                _campusPulse(),
                if (!tablet) ...[
                  const SizedBox(height: 20),
                  _momentum(),
                ],
                const SizedBox(height: 26),
                _toolkit(tablet),
                const SizedBox(height: 35),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 49,
          height: 49,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CampusOS',
                style: TextStyle(
                  color: _ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'STUDY SMARTER. GO FURTHER.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Change appearance',
          onPressed: _appearanceSheet,
          icon: Icon(
            _dark
                ? Icons.nights_stay_rounded
                : Icons.wb_sunny_outlined,
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _comingSoon('Notifications'),
          icon: const Icon(
            Icons.notifications_none_rounded,
          ),
        ),
      ],
    );
  }

  Widget _hero() {
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final movement = reducedMotion
            ? 0.0
            : math.sin(_animation.value * math.pi * 2) * 6;

        return Container(
          constraints: const BoxConstraints(minHeight: 275),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _dark
                  ? [
                      const Color(0xFF514784),
                      const Color(0xFF373050),
                    ]
                  : [
                      const Color(0xFF917EFF),
                      const Color(0xFF6C55E8),
                      const Color(0xFF4833B7),
                    ],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 55 + movement,
                right: 8,
                child: Transform.rotate(
                  angle: -0.15,
                  child: Container(
                    width: 95,
                    height: 95,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFFA8F0D0),
                      size: 55,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '✦  YOUR STUDY SPACE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Don\'t just read.\nRemember what\nyou study.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 21),
                    FilledButton.icon(
                      onPressed: () =>
                          _comingSoon('Quick Study'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFA8F0D0),
                        foregroundColor:
                            const Color(0xFF202037),
                      ),
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                      ),
                      label: const Text('Start studying'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dailyMissions() {
    final percentage = (_progress * 100).round();

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Your daily mission'),
          const SizedBox(height: 8),
          Text(
            'Every completed task moves you forward.',
            style: TextStyle(
              color: _muted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: _soft,
                        color: _accent,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  percentage == 100
                      ? 'You did it! Every mission is complete.'
                      : '${_missions.length - _completed.length} missions remaining today.',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ...List.generate(_missions.length, (index) {
            final checked = _completed.contains(index);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: checked
                    ? _accent.withValues(alpha: 0.12)
                    : _soft,
                borderRadius: BorderRadius.circular(15),
                child: CheckboxListTile(
                  value: checked,
                  activeColor: _accent,
                  controlAffinity:
                      ListTileControlAffinity.leading,
                  title: Text(
                    _missions[index],
                    style: TextStyle(
                      color: checked ? _muted : _ink,
                      fontSize: 15,
                      height: 1.4,
                      decoration: checked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _completed.add(index);
                      } else {
                        _completed.remove(index);
                      }
                    });
                  },
                ),
              ),
            );
          }),
          const SizedBox(height: 5),
          Text(
            'Preview missions. Progress is not saved yet.',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _campusPulse() {
    const periods = ['Today', 'This week', 'This month'];

    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Campus Pulse'),
          const SizedBox(height: 6),
          Text(
            'We grow better together.',
            style: TextStyle(
              color: _muted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(3, (index) {
              final selected = _period == index;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == 2 ? 0 : 7,
                  ),
                  child: Material(
                    color: selected ? _accent : _soft,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _period = index);
                      },
                      child: Container(
                        constraints:
                            const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(7),
                        child: Text(
                          periods[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                : _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_graph_rounded,
                  color: _accent,
                  size: 29,
                ),
                const SizedBox(height: 12),
                Text(
                  'Campus Pulse is warming up',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Verified community goal-completion data for ${periods[_period].toLowerCase()} will appear when enough students opt in.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _milestone('Reached 100% of their goals'),
          _milestone('Reached at least 90%'),
          _milestone('Reached at least 50%'),
          Text(
            'No fabricated participation or progress statistics.',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _milestone(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'Awaiting data',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _momentum() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Your momentum'),
          const SizedBox(height: 8),
          Text(
            'Celebrate every step forward.',
            style: TextStyle(
              color: _muted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _metric(
                  Icons.local_fire_department_rounded,
                  '—',
                  'Study streak',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  Icons.track_changes_rounded,
                  '${(_progress * 100).round()}%',
                  'Today\'s goals',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Streaks activate when study history is connected.',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 25),
          const SizedBox(height: 13),
          Text(
            value,
            style: TextStyle(
              color: _ink,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolkit(bool tablet) {
    final tools = [
      (
        Icons.library_books_rounded,
        'My Courses',
        'Manage your semester courses.',
        1,
      ),
      (
        Icons.calendar_month_rounded,
        'Lecture Timetable',
        'Organize your weekly lectures.',
        2,
      ),
      (
        Icons.auto_stories_rounded,
        'Smart Recall',
        'Remember more of what you study.',
        0,
      ),
      (
        Icons.note_alt_rounded,
        'Lesson Notes',
        'Keep your course notes together.',
        0,
      ),
      (
        Icons.event_note_rounded,
        'Study Planner',
        'Turn your goals into a plan.',
        0,
      ),
      (
        Icons.school_rounded,
        'CGPA Simulator',
        'See what grades you need.',
        0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Your academic toolkit'),
        const SizedBox(height: 17),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = tablet ? 3 : 1;
            const gap = 12.0;
            final width = (constraints.maxWidth -
                    gap * (columns - 1)) /
                columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: tools.map((tool) {
                return SizedBox(
                  width: width,
                  child: Material(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        switch (tool.$4) {
                          case 1:
                            _open(const CoursesScreen());
                            break;
                          case 2:
                            _open(
                              const LectureTimetableScreen(),
                            );
                            break;
                          default:
                            _comingSoon(tool.$2);
                        }
                      },
                      child: Container(
                        constraints:
                            const BoxConstraints(minHeight: 88),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _accent.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius:
                                    BorderRadius.circular(13),
                              ),
                              child: Icon(
                                tool.$1,
                                color: _accent,
                                size: 25,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tool.$2,
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    tool.$3,
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: _muted,
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
        ),
      ],
    );
  }
}