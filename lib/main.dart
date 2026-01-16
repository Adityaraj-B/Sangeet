import 'package:flutter/material.dart';
import 'package:sangeet/routes.dart';
import 'package:sangeet/screens/body.dart';
import 'package:sangeet/screens/sign_in/sign_in_body.dart';
import 'package:sangeet/services/auth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Helper to decide which initial route to use
  Future<String> _chooseInitialRoute() async {
    final logged = await AuthService.isLoggedIn();
    return logged ? Body.routeName : sign_in_body.routeName;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sangeet Music App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'PlayfairDisplay',
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        // Add this to prevent Material 3 from overriding custom transitions
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      // keep routes map as before
      routes: routes,
      // Use a splash router as the app's home so we can decide where to go without changing other navigation code.
      home: const SplashRouter(),
    );
  }
}

/// A small widget that checks login state and redirects accordingly.
/// Keeps your existing routes and `body.routeName` untouched.
class SplashRouter extends StatefulWidget {
  const SplashRouter({Key? key}) : super(key: key);

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
    // Delay is optional — shows the circular spinner briefly so user sees something
    // await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (logged) {
      // Navigate to your body/home route (keeps your existing routes intact)
      Navigator.of(context).pushReplacementNamed(Body.routeName);
    } else {
      // Navigate to sign-in route; ensure routes map contains this key
      Navigator.of(context).pushReplacementNamed(sign_in_body.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple centered progress indicator while we check login state.
    // Keep styling consistent with your app theme.
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}