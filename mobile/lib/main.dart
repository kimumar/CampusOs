import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/course_storage.dart';
import 'services/lecture_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await CourseStorage.initialize();
    await LectureStorage.initialize();
  } catch (error, stackTrace) {
    debugPrint('CampusOS storage error: $error');
    debugPrintStack(stackTrace: stackTrace);

    runApp(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storage_rounded,
                      size: 52,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(height: 18),
                    Text(
                      'CampusOS could not open local storage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Please restart the app. Your stored records '
                      'have not been intentionally cleared.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(const CampusOSApp());
}

enum CampusAppearance {
  system,
  light,
  dark,
  nightComfort,
}

class CampusOSApp extends StatefulWidget {
  const CampusOSApp({super.key});

  @override
  State<CampusOSApp> createState() => _CampusOSAppState();
}

class _CampusOSAppState extends State<CampusOSApp> {
  CampusAppearance _appearance = CampusAppearance.system;

  void _changeAppearance(CampusAppearance appearance) {
    setState(() {
      _appearance = appearance;
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData selectedTheme;
    ThemeMode selectedMode;

    switch (_appearance) {
      case CampusAppearance.system:
        selectedTheme = CampusTheme.light;
        selectedMode = ThemeMode.system;
        break;
      case CampusAppearance.light:
        selectedTheme = CampusTheme.light;
        selectedMode = ThemeMode.light;
        break;
      case CampusAppearance.dark:
        selectedTheme = CampusTheme.dark;
        selectedMode = ThemeMode.dark;
        break;
      case CampusAppearance.nightComfort:
        selectedTheme = CampusTheme.nightComfort;
        selectedMode = ThemeMode.dark;
        break;
    }

    return MaterialApp(
      title: 'CampusOS',
      debugShowCheckedModeBanner: false,
      theme: selectedTheme,
      darkTheme: _appearance == CampusAppearance.system
          ? CampusTheme.dark
          : selectedTheme,
      themeMode: selectedMode,
      home: HomeScreen(
        appearance: _appearance,
        onAppearanceChanged: _changeAppearance,
      ),
    );
  }
}