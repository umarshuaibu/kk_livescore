import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'admins/app_manager/app_manager_signup.dart';
import 'admins/app_manager/app_manager_login.dart';
import 'firebase_options.dart'; // Auto-generated Firebase options file

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/app_manager_signup_screen',
        builder: (context, state) => const AppManagerSignupScreen(),
      ),
      GoRoute(
        path: '/app_manager_login_screen',
        builder: (context, state) => const AppManagerLoginScreen(),
      ),
    ],
    initialLocation: '/app_manager_signup_screen', // Starting screen
  );

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}