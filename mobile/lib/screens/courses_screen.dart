import 'package:flutter/material.dart';

import '../models/campus_course.dart';
import '../services/course_storage.dart';
import '../widgets/campus_dialog.dart';
import '../widgets/campus_form_sheet.dart';
import '../widgets/campus_responsive.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<CampusCourse> _courses = [];
  String _search = '';
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
    });
  }

  int get _totalUnits => _courses.fold<int>(
        0,
        (total, course) => total + course.units,
      );

  List<CampusCourse> get _visibleCourses {
    final query = _search.trim().toLowerCase();
    return _courses.where((course) {
      return course.code.toLowerCase().contains(query) ||
          course.title.toLowerCase().contains(query);
    }).toList();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editCourse({CampusCourse? existing}) async {
    if (_busy) return;

    final codeController = TextEditingController(
      text: existing?.code ?? '',
    );
    final titleController = TextEditingController(
      text: existing?.title ?? '',
    );
    final formKey = GlobalKey<FormState>();

    int units = existing?.units ?? 3;
    bool saving = false;

    try {
      await CampusFormSheet.show<void>(
        context: context,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, updateSheet) {
              Future<void> save() async {
                if (saving) return;
                if (formKey.currentState?.validate() != true) {
                  return;
                }

                updateSheet(() => saving = true);

                final now = DateTime.now().toUtc();
                final course = CampusCourse(
                  id: existing?.id ??
                      now.microsecondsSinceEpoch.toString(),
                  code: codeController.text.trim().toUpperCase(),
                  title: titleController.text.trim(),
                  units: units,
                  createdAt: existing?.createdAt ?? now,
                  updatedAt: now,
                  isDeleted: false,
                  syncVersion: existing?.syncVersion ?? 0,
                );

                try {
                  await CourseStorage.saveCourse(course);
                  if (!mounted) return;
                  _refresh();

                  if (sheetContext.mounted) {
                    Navigator.pop(sheetContext);
                  }
                } catch (_) {
                  _message('Unable to save course. Try again.');
                  if (sheetContext.mounted) {
                    updateSheet(() => saving = false);
                  }
                }
              }

              return CampusFormSheet(
                title: existing == null
                    ? 'Add a course'
                    : 'Edit course',
                subtitle: 'Organize your semester in one place.',
                primaryLabel: existing == null
                    ? 'Save course'
                    : 'Save changes',
                onPrimaryPressed: saving ? null : save,
                isSaving: saving,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: codeController,
                        enabled: !saving,
                        maxLength: 20,
                        textCapitalization:
                            TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Course code',
                          hintText: 'CSC 301',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                        validator: (value) {
                          final code =
                              value?.trim().toUpperCase() ?? '';
                          if (code.isEmpty) {
                            return 'Enter a course code';
                          }
                          if (CourseStorage.courseCodeExists(
                            code,
                            excludeId: existing?.id,
                          )) {
                            return 'This course already exists';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleController,
                        enabled: !saving,
                        maxLength: 100,
                        textCapitalization:
                            TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Course title',
                          hintText: 'Data Structures',
                          prefixIcon:
                              Icon(Icons.menu_book_rounded),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter a course title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: units,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Credit units',
                          prefixIcon:
                              Icon(Icons.school_outlined),
                        ),
                        items: List.generate(10, (index) {
                          final number = index + 1;
                          return DropdownMenuItem(
                            value: number,
                            child: Text(
                              '$number ${number == 1 ? "unit" : "units"}',
                            ),
                          );
                        }),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  updateSheet(() => units = value);
                                }
                              },
                      ),
                    ],
                  ),
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
    }
  }

  Future<void> _deleteCourse(CampusCourse course) async {
    if (_busy) return;

    final confirmed = await CampusDialog.confirm(
      context: context,
      title: 'Delete this course?',
      message:
          'Remove ${course.code} from your active courses? '
          'Existing lecture records will not be automatically deleted.',
      confirmLabel: 'Delete',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    setState(() => _busy = true);

    try {
      await CourseStorage.deleteCourse(course);
      if (!mounted) return;
      _refresh();
      _message('${course.code} removed');
    } catch (_) {
      _message('Unable to remove course.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Courses',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _editCourse(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add course'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              CampusResponsive.pagePadding(context),
              18,
              CampusResponsive.pagePadding(context),
              110,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: colors.primary,
                      size: 38,
                    ),
                    const SizedBox(width: 17),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_courses.length} registered courses',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '$_totalUnits total credit units',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                onChanged: (value) {
                  setState(() => _search = value);
                },
                decoration: const InputDecoration(
                  hintText: 'Search your courses',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 22),
              if (_courses.isEmpty)
                _emptyState(theme)
              else if (_visibleCourses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    'No matching courses found.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                )
              else
                ..._visibleCourses.map(
                  (course) => _courseCard(course, theme),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
        vertical: 48,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(
            Icons.library_books_outlined,
            color: theme.colorScheme.primary,
            size: 58,
          ),
          const SizedBox(height: 17),
          Text(
            'Your courses start here',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Add your semester courses to organize '
            'lectures, notes, and revision.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : () => _editCourse(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add your first course'),
          ),
        ],
      ),
    );
  }

  Widget _courseCard(
    CampusCourse course,
    ThemeData theme,
  ) {
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    course.code,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.title,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${course.units} credit units',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Course options',
              enabled: !_busy,
              onSelected: (value) {
                if (value == 'edit') {
                  _editCourse(existing: course);
                } else if (value == 'delete') {
                  _deleteCourse(course);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}