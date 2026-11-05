import 'package:flutter/material.dart';

import 'core/app_theme.dart';

void main() {
  runApp(const CampusOSApp());
}

class CampusOSApp extends StatelessWidget {
  const CampusOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusOS',
      debugShowCheckedModeBanner: false,
      theme: CampusTheme.light,
      home: const CampusHomeScreen(),
    );
  }
}

class CampusHomeScreen extends StatelessWidget {
  const CampusHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CampusOS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 72,
                  color: CampusColors.violet,
                ),
                SizedBox(height: 24),
                Text(
                  'Your academic comeback starts here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: CampusColors.ink,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Don't just read. Remember what you study.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: CampusColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}