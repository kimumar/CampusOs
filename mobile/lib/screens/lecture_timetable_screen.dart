import '../services/cloud_sync.dart';
import 'package:flutter/material.dart';

import '../models/campus_course.dart';
import '../models/lecture_session.dart';
import '../services/course_storage.dart';
import '../services/lecture_storage.dart';
import '../widgets/campus_empty_state.dart';
import '../widgets/campus_form_sheet.dart';
import '../widgets/campus_lecture_card.dart';
import 'courses_screen.dart';

class LectureTimetableScreen extends StatefulWidget {
  const LectureTimetableScreen({super.key});

  @override
  State<LectureTimetableScreen> createState() =>
      _LectureTimetableScreenState();
}

class _LectureTimetableScreenState
    extends State<LectureTimetableScreen> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  List<CampusCourse> _courses = [];
  List<LectureSession> _lectures = [];

  int _selectedDay = DateTime.now().weekday;
  bool _showAll = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;

    setState(() {
      _courses = CourseStorage.getCourses();
      _lectures = LectureStorage.getLectures();
    });
  }

  CampusCourse? _courseFor(String id) {
    for (final course in _courses) {
      if (course.id == id) return course;
    }
    return null;
  }

  String _courseCode(LectureSession lecture) {
    if (lecture.isManual) {
      return lecture.manualCourseCode;
    }

    return _courseFor(lecture.courseId)?.code ??
        'Archived course';
  }

  String _courseTitle(LectureSession lecture) {
    if (lecture.isManual) {
      return lecture.manualCourseTitle.isEmpty
          ? 'Independent timetable entry'
          : lecture.manualCourseTitle;
    }

    return _courseFor(lecture.courseId)?.title ??
        'Course no longer registered';
  }

  String _time(int minute) {
    final hour = minute ~/ 60;
    final min = minute % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return '$displayHour:'
        '${min.toString().padLeft(2, '0')} $period';
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openCourses() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CoursesScreen(),
      ),
    );

    if (mounted) {
      _refresh();
    }
  }

  Future<void> _editLecture({
    LectureSession? existing,
  }) async {
    if (_busy) return;

    _refresh();

    bool manual = existing?.isManual ?? _courses.isEmpty;
    String courseId = existing?.courseId ?? '';

    if (!manual &&
        !_courses.any((course) => course.id == courseId)) {
      courseId = _courses.isNotEmpty
          ? _courses.first.id
          : '';
    }

    final codeController = TextEditingController(
      text: existing?.manualCourseCode ?? '',
    );

    final titleController = TextEditingController(
      text: existing?.manualCourseTitle ?? '',
    );

    final venueController = TextEditingController(
      text: existing?.venue ?? '',
    );

    final lecturerController = TextEditingController(
      text: existing?.lecturer ?? '',
    );

    int day = existing?.day ?? _selectedDay;

    TimeOfDay start = existing == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(
            hour: existing.startMinute ~/ 60,
            minute: existing.startMinute % 60,
          );

    TimeOfDay end = existing == null
        ? const TimeOfDay(hour: 11, minute: 0)
        : TimeOfDay(
            hour: existing.endMinute ~/ 60,
            minute: existing.endMinute % 60,
          );

    bool saving = false;

    try {
      await CampusFormSheet.show<void>(
        context: context,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, updateSheet) {
              Future<void> chooseTime(
                bool chooseStart,
              ) async {
                final selected = await showTimePicker(
                  context: context,
                  initialTime: chooseStart ? start : end,
                );

                if (selected == null ||
                    !sheetContext.mounted) {
                  return;
                }

                updateSheet(() {
                  if (chooseStart) {
                    start = selected;
                  } else {
                    end = selected;
                  }
                });
              }

              Future<void> save() async {
                if (saving) return;

                final code =
                    codeController.text.trim().toUpperCase();

                if (manual && code.isEmpty) {
                  _message('Enter a course code.');
                  return;
                }

                if (!manual && courseId.isEmpty) {
                  _message('Select a course.');
                  return;
                }

                final startMinute =
                    start.hour * 60 + start.minute;

                final endMinute =
                    end.hour * 60 + end.minute;

                if (endMinute <= startMinute) {
                  _message(
                    'End time must be later than start time.',
                  );
                  return;
                }

                final now = DateTime.now().toUtc();

                final candidate = LectureSession(
                  id: existing?.id ??
                      now.microsecondsSinceEpoch.toString(),
                  courseId: manual ? '' : courseId,
                  manualCourseCode: manual ? code : '',
                  manualCourseTitle: manual
                      ? titleController.text.trim()
                      : '',
                  day: day,
                  startMinute: startMinute,
                  endMinute: endMinute,
                  venue: venueController.text.trim(),
                  lecturer: lecturerController.text.trim(),
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                  isDeleted: false,
                  syncVersion: existing?.syncVersion ?? 0,
                );

                final conflict =
                    LectureStorage.findConflict(candidate);

                if (conflict != null) {
                  _message(
                    'Time overlaps with '
                    '${_courseCode(conflict)}. '
                    'Choose another time.',
                  );
                  return;
                }

                updateSheet(() => saving = true);

                try {
                  await LectureStorage.saveLecture(
                    candidate,
                  );
                  CloudSync.queueSync();

                  if (!mounted) return;

                  setState(() {
                    _selectedDay = day;
                    _showAll = false;
                  });

                  _refresh();

                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                } catch (_) {
                  _message('Could not save lecture.');

                  if (sheetContext.mounted) {
                    updateSheet(() => saving = false);
                  }
                }
              }

              return CampusFormSheet(
                title: existing == null
                    ? 'Add a lecture'
                    : 'Edit lecture',
                subtitle:
                    'Set up a repeating weekly lecture.',
                primaryLabel: existing == null
                    ? 'Save lecture'
                    : 'Save changes',
                onPrimaryPressed: saving ? null : save,
                isSaving: saving,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'How would you like to add your course?',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Select existing'),
                          icon: Icon(
                            Icons.library_books_outlined,
                          ),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Enter manually'),
                          icon: Icon(Icons.edit_outlined),
                        ),
                      ],
                      selected: {manual},
                      onSelectionChanged: saving
                          ? null
                          : (values) {
                              updateSheet(() {
                                manual = values.first;
                              });
                            },
                    ),
                    const SizedBox(height: 18),
                    if (!manual) ...[
                      if (_courses.isEmpty)
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'No registered courses yet.',
                            ),
                            TextButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      Navigator.pop(
                                        sheetContext,
                                      );
                                      await _openCourses();
                                    },
                              icon: const Icon(
                                Icons.add_rounded,
                              ),
                              label: const Text(
                                'Register a course',
                              ),
                            ),
                          ],
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'linked-${existing?.id ?? "new"}',
                          ),
                          initialValue: courseId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText:
                                'Registered course',
                            prefixIcon: Icon(
                              Icons.menu_book_rounded,
                            ),
                          ),
                          items: _courses.map((course) {
                            return DropdownMenuItem<String>(
                              value: course.id,
                              child: Text(
                                '${course.code} — ${course.title}',
                                overflow:
                                    TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: saving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    updateSheet(() {
                                      courseId = value;
                                    });
                                  }
                                },
                        ),
                    ] else ...[
                      TextFormField(
                        controller: codeController,
                        enabled: !saving,
                        maxLength: 20,
                        textCapitalization:
                            TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Course code',
                          hintText: 'PHY 202',
                          prefixIcon:
                              Icon(Icons.tag_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: titleController,
                        enabled: !saving,
                        maxLength: 100,
                        textCapitalization:
                            TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText:
                              'Course title (optional)',
                          hintText: 'Applied Physics',
                          prefixIcon: Icon(
                            Icons.menu_book_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This course will be used only '
                        'for this lecture. It will not '
                        'automatically be registered '
                        'in Course Management.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall,
                      ),
                    ],
                    const SizedBox(height: 18),
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        'day-${existing?.id ?? "new"}',
                      ),
                      initialValue: day,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Lecture day',
                        prefixIcon: Icon(
                          Icons.calendar_today_rounded,
                        ),
                      ),
                      items: List.generate(
                        7,
                        (index) => DropdownMenuItem<int>(
                          value: index + 1,
                          child: Text(_days[index]),
                        ),
                      ),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                updateSheet(() {
                                  day = value;
                                });
                              }
                            },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => chooseTime(true),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                const Text('Starts'),
                                Text(
                                  _time(
                                    start.hour * 60 +
                                        start.minute,
                                  ),
                                  textAlign:
                                      TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => chooseTime(false),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                const Text('Ends'),
                                Text(
                                  _time(
                                    end.hour * 60 +
                                        end.minute,
                                  ),
                                  textAlign:
                                      TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: venueController,
                      enabled: !saving,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Venue (optional)',
                        hintText: 'LT 2',
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lecturerController,
                      enabled: !saving,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Lecturer (optional)',
                        hintText: 'Dr. Ade',
                        prefixIcon: Icon(
                          Icons.person_outline_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      await Future<void>.delayed(
        const Duration(milliseconds: 400),
      );

      codeController.dispose();
      titleController.dispose();
      venueController.dispose();
      lecturerController.dispose();
    }
  }

  Future<void> _deleteLecture(
    LectureSession lecture,
  ) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove lecture?'),
        content: Text(
          'Remove ${_courseCode(lecture)} '
          'from your weekly timetable?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    try {
      await LectureStorage.deleteLecture(lecture);
      CloudSync.queueSync();

      if (!mounted) return;

      _refresh();
      _message('Lecture removed.');
    } catch (_) {
      _message('Unable to remove lecture.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _lectureCard(LectureSession lecture) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampusLectureCard(
          lecture: lecture,
          courseCode: _courseCode(lecture),
          courseTitle: _courseTitle(lecture),
          onTap: _busy
              ? null
              : () => _editLecture(existing: lecture),
          busy: _busy,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _busy
                ? null
                : () => _deleteLecture(lecture),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
            ),
            label: const Text('Remove lecture'),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final visible = _showAll
        ? _lectures
        : _lectures
            .where(
              (lecture) =>
                  lecture.day == _selectedDay,
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lecture Timetable',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Manage courses',
            onPressed: _openCourses,
            icon: const Icon(
              Icons.library_books_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _busy
            ? null
            : () => _editLecture(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add lecture'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              110,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.primary
                      .withValues(alpha: 0.11),
                  borderRadius:
                      BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: colors.primary,
                      size: 36,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your weekly schedule',
                            style:
                                theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${_lectures.length} recurring '
                            'lectures • Available offline',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('By day'),
                    icon: Icon(
                      Icons.today_rounded,
                    ),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Full week'),
                    icon: Icon(
                      Icons.view_week_rounded,
                    ),
                  ),
                ],
                selected: {_showAll},
                onSelectionChanged: (selection) {
                  setState(() {
                    _showAll = selection.first;
                  });
                },
              ),
              if (!_showAll) ...[
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      7,
                      (index) {
                        final day = index + 1;

                        return Padding(
                          padding:
                              const EdgeInsets.only(
                            right: 7,
                          ),
                          child: ChoiceChip(
                            label: Text(
                              _days[index].substring(
                                0,
                                3,
                              ),
                            ),
                            selected:
                                day == _selectedDay,
                            onSelected: (_) {
                              setState(() {
                                _selectedDay = day;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Text(
                _showAll
                    ? 'All weekly lectures'
                    : _days[_selectedDay - 1],
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                CampusEmptyState(
                  icon:
                      Icons.event_note_rounded,
                  title:
                      'No lectures scheduled',
                  message:
                      'Select a registered course '
                      'or enter one manually.',
                  action: _busy
                      ? null
                      : () => _editLecture(),
                  actionLabel: 'Add lecture',
                )
              else
                ...visible.map(_lectureCard),
              const SizedBox(height: 16),
              Text(
                'Weekly recurring timetable. '
                'One-off cancellations and '
                'attendance tracking will be '
                'added separately.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}