import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;
  final tasks = <String>['Review yesterday’s notes', 'Practice 10 recall questions', 'Study for 25 minutes'];
  final completed = <int>{0};

  @override
  Widget build(BuildContext context) {
    const violet = Color(0xFF6C55E8);
    const ink = Color(0xFF202037);
    const ivory = Color(0xFFF8F7FC);
    final progress = completed.length / tasks.length;
    return Scaffold(
      backgroundColor: ivory,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
                    sliver: SliverList(delegate: SliverChildListDelegate([
                      Row(children: [
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('CampusOS', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: ink)),
                          SizedBox(height: 4),
                          Text('Make today count ✨', style: TextStyle(fontSize: 13, color: Color(0xFF77758C))),
                        ])),
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.notifications_none_rounded, color: ink)),
                      ]),
                      const SizedBox(height: 28),
                      const Text('Your comeback starts here.', style: TextStyle(fontSize: 30, height: 1.13, fontWeight: FontWeight.w900, letterSpacing: -1.1, color: ink)),
                      const SizedBox(height: 9),
                      const Text('Small wins today. Big results tomorrow.', style: TextStyle(fontSize: 14, color: Color(0xFF77758C))),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(23),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8674F7), violet, Color(0xFF4833BD)]),
                          borderRadius: BorderRadius.circular(29),
                          boxShadow: const [BoxShadow(color: Color(0x446C55E8), blurRadius: 25, offset: Offset(0, 13))],
                        ),
                        child: Stack(children: [
                          Positioned(right: -16, top: -24, child: Icon(Icons.auto_stories_rounded, size: 142, color: Colors.white.withValues(alpha: 0.14))),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.17), borderRadius: BorderRadius.circular(40)), child: const Text('✦ YOUR STUDY SPACE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1))),
                            const SizedBox(height: 20),
                            const Text('Ready to learn\nsomething amazing?', style: TextStyle(color: Colors.white, fontSize: 25, height: 1.16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            const Text('Don’t just read. Remember what you study.', style: TextStyle(color: Color(0xFFE7E1FF), fontSize: 12.5)),
                            const SizedBox(height: 21),
                            FilledButton.icon(
                              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Study mode is coming next.'))),
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFA8F0D0), foregroundColor: ink, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                              icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start studying', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 30),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Daily mission', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink)),
                        Text('${completed.length}/${tasks.length} done', style: const TextStyle(color: violet, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 13),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFF0EDF8))),
                        child: Column(children: [
                          Row(children: [
                            const Icon(Icons.bolt_rounded, color: Color(0xFFF0B64B)),
                            const SizedBox(width: 7),
                            const Expanded(child: Text('Keep your momentum', style: TextStyle(fontWeight: FontWeight.w800, color: ink))),
                            Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900, color: violet)),
                          ]),
                          const SizedBox(height: 12),
                          ClipRRect(borderRadius: BorderRadius.circular(30), child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: const Color(0xFFEEEAFB), color: violet)),
                          const SizedBox(height: 12),
                          ...List.generate(tasks.length, (i) => CheckboxListTile(
                            value: completed.contains(i),
                            onChanged: (value) => setState(() { if (value == true) { completed.add(i); } else { completed.remove(i); } }),
                            title: Text(tasks[i], style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, decoration: completed.contains(i) ? TextDecoration.lineThrough : null)),
                            activeColor: violet, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading,
                          )),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      Row(children: [
                        Expanded(child: _MetricCard(icon: Icons.local_fire_department_rounded, label: 'Study streak', value: '3 days', tint: const Color(0xFFFFEAC9), iconColor: const Color(0xFFDA8A2C))),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricCard(icon: Icons.track_changes_rounded, label: 'Weekly goal', value: '68%', tint: const Color(0xFFDDF9EA), iconColor: const Color(0xFF24865D))),
                      ]),
                      const SizedBox(height: 22),
                      const Text('Your progress, your pace.', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: ink)),
                      const SizedBox(height: 7),
                      const Text('You’re building a better study habit, one day at a time.', style: TextStyle(color: Color(0xFF77758C), fontSize: 13)),
                    ])),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFECE7FF),
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
          if (index != 0) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${['Home', 'Study', 'Planner', 'Profile'][index]} screen is coming next.')));
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.auto_stories_outlined), label: 'Study'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Planner'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.label, required this.value, required this.tint, required this.iconColor});
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color iconColor;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23), border: Border.all(color: const Color(0xFFF0EDF8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: iconColor)),
        const SizedBox(height: 13),
        Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Color(0xFF202037))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF77758C))),
      ]),
    );
  }
}