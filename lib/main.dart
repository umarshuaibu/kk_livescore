import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kklivescoreadmin/screens/player_list_screen.dart';
import 'package:kklivescoreadmin/screens/coach_list_screen.dart';
import 'admins/app_manager/admin_login.dart';
import 'firebase_options.dart';
import 'admins/app_manager/admin_dashboard.dart';
import 'package:app_links/app_links.dart';
import 'screens/create_team_screen.dart';
import 'screens/create_coach_screen.dart';
import 'screens/create_player_screen.dart';
// ignore: unused_import
import 'dart:async';

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
        path: '/admin_login_screen',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return AppManagerLoginScreen(token: token);
        },
      ),
      GoRoute(
        path: '/admin_dashboard',
        builder: (context, state) {
          return AdminDashboard();
        },
      ),

      GoRoute(
        path: '/screens/playerlist',
        builder: (context, state) {
          return PlayerListScreen();
        },
      ),

      GoRoute(
        path: '/screens/coachlist',
        builder: (context, state) {
          return CoachListScreen();
        },
      ),
      GoRoute(
        path: '/screens/create_team',
        builder: (context, state) {
          return CreateTeamScreen();
        },
      ),
      GoRoute(
        path: '/screens/create_player',
        builder: (context, state) {
          return CreatePlayerScreen();
        },
      ),
        GoRoute(
        path: '/screens/create_coach',
        builder: (context, state) {
          return CreateCoachScreen();
        },
      ),

    ],
    //initialLocation: '/admin_login_screen',
    initialLocation: '/admin_dashboard',
  );

  MyApp({super.key}) {
    final appLinks = AppLinks();
    appLinks.getInitialAppLink().then((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
    appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    if (uri.path == '/admin_login_screen') {
      _router.go('/app_manager_login_screen${uri.query.isNotEmpty ? '?${uri.query}' : ''}');
    } else {
      _router.go('/admin_login_screen');
    }
  }

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