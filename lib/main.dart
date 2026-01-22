import 'package:flutter/material.dart';
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
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialize audio service after first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioPlayerService().initialize();
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
