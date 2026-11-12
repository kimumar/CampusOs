import 'package:flutter/material.dart';
import '../services/course_storage.dart';
import '../services/grade_calculator.dart';

class CgpaSimulatorScreen extends StatefulWidget {
  const CgpaSimulatorScreen({super.key});
  @override
  State<CgpaSimulatorScreen> createState() => _CgpaSimulatorScreenState();
}

class _CgpaSimulatorScreenState extends State<CgpaSimulatorScreen> {
  bool useFivePoint = true;
  final selectedGrades = <String, String>{};
  final previousCgpa = TextEditingController(text: '0');
  final previousUnits = TextEditingController(text: '0');

  @override
  void dispose() { previousCgpa.dispose(); previousUnits.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final courses = CourseStorage.getCourses();
    final scale = useFivePoint ? GradeCalculator.fivePoint : GradeCalculator.fourPoint;
    final entries = <(int, int)>[];
    var totalCurrentUnits = 0;
    var totalPoints = 0.0;
    for (final course in courses) {
      final grade = selectedGrades[course.id];
      final score = scale[grade];
      if (score == null) continue;
      entries.add((course.units, score));
      totalCurrentUnits += course.units;
      totalPoints += course.units * score;
    }
    final gpa = GradeCalculator.weightedAverage(entries);
    final oldUnits = int.tryParse(previousUnits.text) ?? -1;
    final oldCgpa = double.tryParse(previousCgpa.text) ?? -1;
    final maxGrade = useFivePoint ? 5.0 : 4.0;
    final validPrevious = oldUnits >= 0 && oldCgpa >= 0 && oldCgpa <= maxGrade;
    final cgpa = validPrevious && gpa != null ? GradeCalculator.projectedCgpa(
      previousCgpa: oldCgpa, previousUnits: oldUnits,
      currentUnits: totalCurrentUnits, currentGradePoints: totalPoints) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('CGPA Goal Simulator')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Explore your grade scenarios', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('These are projections only. Select your school\'s grading scale and expected course grades.'),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('5-point scale')),
                ButtonSegment(value: false, label: Text('4-point scale')),
              ],
              selected: {useFivePoint},
              onSelectionChanged: (values) => setState(() {
                useFivePoint = values.first;
                selectedGrades.clear();
              }),
            ),
          ],
        ))),
        const SizedBox(height: 14),
        if (courses.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16),
          child: Text('Add courses and credit units first to simulate your GPA.'))),
        for (final course in courses)
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${course.code} · ${course.units} units'),
            ])),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: selectedGrades[course.id],
              hint: const Text('Grade'),
              items: [for (final entry in scale.entries)
                DropdownMenuItem(value: entry.key, child: Text('${entry.key} (${entry.value})'))],
              onChanged: (value) => setState(() {
                if (value != null) selectedGrades[course.id] = value;
              }),
            ),
          ]))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Projected semester GPA', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(gpa == null ? 'Choose grades above' : gpa.toStringAsFixed(2),
              style: Theme.of(context).textTheme.headlineMedium),
            Text('Based on $totalCurrentUnits selected credit units'),
          ],
        ))),
        const SizedBox(height: 16),
        Text('Previous academic record (optional)', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: previousCgpa, keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}), decoration: const InputDecoration(
              labelText: 'Previous CGPA', border: OutlineInputBorder()))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: previousUnits, keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}), decoration: const InputDecoration(
              labelText: 'Previous total units', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Projected cumulative CGPA', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(cgpa == null ? '—' : cgpa.toStringAsFixed(2),
              style: Theme.of(context).textTheme.headlineMedium),
            if (!validPrevious) const Text('Enter a valid previous CGPA and credit-unit total.'),
          ],
        ))),
        const SizedBox(height: 10),
        const Text('No grade is assumed. Your institution may use a different grading table; verify it before relying on a projection.'),
      ]),
    );
  }
}
