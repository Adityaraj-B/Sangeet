import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:sangeet/constants.dart';
import 'package:sangeet/routes.dart';
import 'package:sangeet/screens/body.dart';
import 'package:sangeet/screens/sign_in/sign_in_body.dart';
import 'package:sangeet/services/auth.dart';
import 'package:sangeet/services/playlist_provider.dart';
import 'package:sangeet/services/like_service.dart';
import 'package:sangeet/services/audio_player_service.dart';
import 'package:sangeet/services/audio_device_service.dart';
import 'package:sangeet/services/notification_permission_service.dart';
import 'dart:io';
import 'firebase_options.dart';

// Global flag to track if audio service has been initialized in main
bool _audioServiceInitStarted = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Don't initialize audio service here - it needs the Activity to be ready
  // It will be initialized after the first frame is rendered

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => PlaylistProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => LikeService()..load(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAudioService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up when app is truly closed
    AudioPlayerService().shutdown();
    AudioDeviceService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.detached) {
      // App is being removed from recents or killed - fully shutdown and exit
      debugPrint('Main: App detached (removed from recents) - shutting down');
      _shutdownAndExit();
    }
    // Note: We don't stop on paused/inactive - that's just minimize, allow background play
  }

  Future<void> _shutdownAndExit() async {
    try {
      // Fully shutdown audio service (stops playback and removes notification)
      await AudioPlayerService().shutdown();
      AudioDeviceService().dispose();
    } catch (e) {
      debugPrint('Main: Error during shutdown: $e');
    }

    // Force close the app completely
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else if (Platform.isIOS) {
      exit(0);
    }
  }

  Future<void> _initializeAudioService() async {
    // Prevent multiple initialization attempts from widget rebuilds
    if (_audioServiceInitStarted) {
      debugPrint('Main: Audio service initialization already started, skipping');
      return;
    }
    _audioServiceInitStarted = true;

    // Wait for the first frame to ensure Activity is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Additional delay to ensure Android Activity is fully initialized
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        // Request notification permission first (required for Android 13+)
        await NotificationPermissionService().requestNotificationPermission();

        // Then initialize audio services
        debugPrint('Main: Starting audio service initialization...');
        await AudioPlayerService().initialize();
        debugPrint('Main: Audio service initialization complete');

        // Initialize audio device service
        AudioDeviceService().initialize();
      } catch (e) {
        debugPrint('Main: Error initializing audio service: $e');
        // Continue anyway - audio will work without notification controls
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sangeet Music App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'PlayfairDisplay',
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      routes: routes,
      home: const SplashRouter(),
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    final logged = await AuthService.isLoggedIn();
    if (!mounted) return;

    if (logged) {
      Navigator.of(context).pushReplacementNamed(Body.routeName);
    } else {
      Navigator.of(context).pushReplacementNamed(SignInBody.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: CircularProgressIndicator(
          color: kAccentColor,
        ),
      ),
    );
  }
}
