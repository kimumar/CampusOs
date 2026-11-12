import 'services/study_draft_storage.dart';
import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'screens/auth_screen.dart';
import 'services/auth_api.dart';
import 'screens/home_screen.dart';
import 'services/course_storage.dart';
import 'services/lecture_storage.dart';
import 'services/profile_storage.dart';
import 'services/cloud_sync.dart';
import 'services/check_in_storage.dart';
import 'services/study_mission_storage.dart';
import 'services/academic_notifications.dart';
import 'screens/restricted_campus_home.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await CourseStorage.initialize();
    await LectureStorage.initialize();
    await ProfileStorage.initialize();
    await StudyMissionStorage.initialize();
    await CheckInStorage.initialize();
    await StudyDraftStorage.initialize();
    await AcademicNotifications.initialize();
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  CampusAppearance _appearance = CampusAppearance.system;
  bool _ready = false;
  bool _authenticated = false;
  @override void initState() {
    super.initState();
    AuthApi.restore().then((ok) {
      if (ok) CloudSync.start();
      if(mounted) setState(() { _ready=true; _authenticated=ok; });
    }).catchError((Object _) {
      if(mounted) setState(() { _ready=true; _authenticated=false; });
    });
  }
  Future<void> _logout() async {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    await AcademicNotifications.cancel();
    await AcademicNotifications.clearHistory();
    CloudSync.stop();
    await AuthApi.logout();
    if(mounted) setState(() => _authenticated=false);
  }
  Future<void> _enter() async {
    CloudSync.start();
    if(mounted) setState(() => _authenticated=true);
  }

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
      navigatorKey: _navigatorKey,
      title: 'CampusOS',
      debugShowCheckedModeBanner: false,
      theme: selectedTheme,
      darkTheme: _appearance == CampusAppearance.system
          ? CampusTheme.dark
          : selectedTheme,
      themeMode: selectedMode,
      home: !_ready ? const Scaffold(body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Image(image:AssetImage('assets/branding/campusos_icon_transparent.png'),height:120),SizedBox(height:16),Text('CampusOS',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),SizedBox(height:20),CircularProgressIndicator()])))
          : !_authenticated ? AuthScreen(onAuthenticated:_enter)
          : CampusAccessGate(appearance:_appearance,onAppearanceChanged:_changeAppearance,onLogout:_logout),
    );
  }
}
class CampusAccessGate extends StatefulWidget {
  const CampusAccessGate({super.key,required this.appearance,required this.onAppearanceChanged,required this.onLogout});
  final CampusAppearance appearance;
  final ValueChanged<CampusAppearance> onAppearanceChanged;
  final Future<void> Function() onLogout;
  @override State<CampusAccessGate> createState()=>_CampusAccessGateState();
}
class _CampusAccessGateState extends State<CampusAccessGate> with WidgetsBindingObserver {
  bool checking=true; String error='';
  Timer? _expiryTicker;
  @override void initState(){
    super.initState();WidgetsBinding.instance.addObserver(this);check();
    _expiryTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || checking) return;
      if (!AuthApi.hasUsableAccess) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        AcademicNotifications.cancel();
        setState(() {});
      }
    });
  }
  @override void dispose(){_expiryTicker?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)check();}
  Future<void> check() async {
    if(mounted)setState(() {checking=true;error='';});
    try {await AuthApi.loadMe();}catch(e){
      if (!await AuthApi.tryOfflineAccess()) {
        error='Unable to verify account access. Connect to the internet and retry.';
      }
    }
    if(error.isEmpty && AuthApi.hasUsableAccess) {
      CloudSync.queueSync();
      AcademicNotifications.reschedule();
    }
    if(mounted)setState(()=>checking=false);
  }
  @override Widget build(BuildContext context){
    if(checking)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    if(error.isNotEmpty||!AuthApi.hasUsableAccess){
      return RestrictedCampusHome(onRetry:check,onLogout:widget.onLogout);
    }
    return HomeScreen(appearance:widget.appearance,onAppearanceChanged:widget.onAppearanceChanged,onLogout:widget.onLogout);
  }
}
