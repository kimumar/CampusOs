import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/profile_storage.dart';

/// Public account shell during expired trial, expired subscription or offline
/// verification timeout. Never mounts private academic tool screens.
class RestrictedCampusHome extends StatefulWidget {
  const RestrictedCampusHome({super.key, required this.onRetry, required this.onLogout});
  final Future<void> Function() onRetry;
  final Future<void> Function() onLogout;
  @override State<RestrictedCampusHome> createState() => _RestrictedCampusHomeState();
}

class _RestrictedCampusHomeState extends State<RestrictedCampusHome> {
  bool profile = false;
  String get firstName {
    final name = ProfileStorage.load().name.trim();
    return name.isEmpty ? 'scholar' : name.split(' ').first;
  }

  @override Widget build(BuildContext context) {
    final account = AuthApi.account;
    final now = DateTime.now();
    final expires = [account?['trial_ends_at'], account?['paid_until'], account?['complimentary_until']]
      .map((value) => DateTime.tryParse((value ?? '').toString())?.toLocal())
      .whereType<DateTime>().toList();
    final genuinelyExpired = account?['complimentary_lifetime'] != true &&
      !expires.any((date) => date.isAfter(now));
    final monthlyPrice = account?['monthly_price_ngn'] ?? 700;
    final quarterlyPrice = account?['quarterly_price_ngn'] ?? 2000;
    final explanation = genuinelyExpired
      ? 'Your 3-day trial or subscription has expired. Your records are safe. Renew your subscription to resume.'
      : 'Your 24-hour offline access has ended. Connect to the internet to verify your active subscription. No extra payment is needed.';
    return Scaffold(
      appBar: AppBar(title: const Text('CampusOS')),
      bottomNavigationBar: NavigationBar(selectedIndex: profile ? 1 : 0,
        onDestinationSelected: (index) => setState(() => profile = index == 1),
        destinations: const [NavigationDestination(icon:Icon(Icons.home_outlined), label:'Home'),
          NavigationDestination(icon:Icon(Icons.person_outline), label:'Profile')]),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          if (!profile) ...[
            const Icon(Icons.school_rounded, size: 74, color: Color(0xFFAE85FF)),
            const SizedBox(height: 24),
            Text('Welcome back, $firstName! 💜', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const Text('You have made progress already. Your next small step still counts.'),
            const SizedBox(height: 12),
            Text(explanation),
            const SizedBox(height: 20),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('CampusOS Premium', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('₦$monthlyPrice monthly  •  ₦$quarterlyPrice quarterly'),
                const SizedBox(height: 8),
                const Text('Payment activation is not configured in this test build.'),
              ]))),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: widget.onRetry, icon: const Icon(Icons.wifi),
              label: const Text('Reconnect and verify access')),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: () => showModalBottomSheet<void>(
                context: context, isScrollControlled: true, showDragHandle: true,
                builder: (_) => const BasicCgpaCalculator()),
              icon: const Icon(Icons.calculate_outlined), label: const Text('Free GPA calculator')),
          ] else ...[
            Text('My Profile', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(Icons.person), title: Text(firstName),
              subtitle: Text((account?['email'] ?? '').toString())),
            const ListTile(leading: Icon(Icons.lock_outline),
              title: Text('Academic records preserved'),
              subtitle: Text('Your saved information remains on this device.')),
          ],
          const SizedBox(height: 16),
          TextButton.icon(onPressed: widget.onLogout,
            icon: const Icon(Icons.logout), label: const Text('Log out')),
        ])))),
    );
  }
}


/// Lightweight calculator available inside the free Home screen.
/// It does not read or change any saved academic records.
class BasicCgpaCalculator extends StatefulWidget {
  const BasicCgpaCalculator({super.key});
  @override State<BasicCgpaCalculator> createState() => _BasicCgpaCalculatorState();
}

class _BasicCgpaCalculatorState extends State<BasicCgpaCalculator> {
  final units = List.generate(5, (_) => TextEditingController());
  final grades = List.filled(5, 'A');
  int scale = 5;
  String answer = '';

  @override void dispose() {
    for (final controller in units) { controller.dispose(); }
    super.dispose();
  }

  void calculate() {
    var totalUnits = 0;
    var points = 0.0;
    for (var i = 0; i < 5; i++) {
      final value = units[i].text.trim();
      if (value.isEmpty) continue;
      final credit = int.tryParse(value);
      if (credit == null || credit < 1 || credit > 15) {
        setState(() => answer = 'Enter valid credit units (1–15) for each course.');
        return;
      }
      totalUnits += credit;
      final gradePoint = <String, int>{'A':scale, 'B':scale - 1,
        'C':scale - 2, 'D':scale - 3, 'E':scale == 5 ? 1 : 0, 'F':0}[grades[i]]!;
      points += credit * gradePoint;
    }
    setState(() => answer = totalUnits == 0 ? 'Enter at least one course.'
      : 'Your estimated GPA: ${(points / totalUnits).toStringAsFixed(2)} / $scale');
  }

  @override Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child: ListView(padding: const EdgeInsets.all(20), shrinkWrap:true, children: [
        Text('Free GPA calculator', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text('An estimate using course credit units. No results are saved.'),
        DropdownButton<int>(value: scale, items: const [
          DropdownMenuItem(value:5, child:Text('5-point scale')),
          DropdownMenuItem(value:4, child:Text('4-point scale'))],
          onChanged: (v) => setState(() {scale = v ?? 5; answer = ''; })),
        for (var i = 0; i < 5; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: TextField(controller: units[i], keyboardType: TextInputType.number,
              decoration: InputDecoration(border: const OutlineInputBorder(), labelText: 'Course ${i + 1} units'))),
            const SizedBox(width: 12),
            DropdownButton<String>(value: grades[i], items: const ['A','B','C','D','E','F']
                .map((grade) => DropdownMenuItem(value:grade, child:Text(grade))).toList(),
              onChanged: (value) => setState(() => grades[i] = value ?? 'A')),
          ])),
        const SizedBox(height: 16),
        FilledButton(onPressed: calculate, child: const Text('Calculate GPA')),
        if (answer.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16),
          child: Text(answer, style: Theme.of(context).textTheme.titleMedium)),
      ]))));
}
