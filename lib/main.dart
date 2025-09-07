import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kklivescoreadmin/screens/player_list_screen.dart';
import 'package:kklivescoreadmin/screens/team_list_screen.dart';
import 'package:kklivescoreadmin/screens/coach_list_screen.dart';
import 'admins/app_manager/admin_login.dart';
import 'firebase_options.dart';
import 'admins/app_manager/admin_panel.dart';
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
        path: '/admin_panel',
        builder: (context, state) {
          return AdminPanel();
        },
      ),

      GoRoute(
        path: '/',
        builder: (context, state) {
          return AdminPanel();
        },
      ),
     GoRoute(
        path: '/create_team',
        builder: (context, state) {
          return CreateTeamScreen();
        },
      ),
      GoRoute(
        path: '/create_player',
        builder: (context, state) {
          return CreatePlayerScreen();
        },
      ),
              GoRoute(
        path: '/create_coach',
        builder: (context, state) {
          return CreateCoachScreen();
        },
      ),
            GoRoute(
        path: '/player_list',
        builder: (context, state) {
          return PlayerListScreen();
        },
      ),

      GoRoute(
        path: '/coach_list',
        builder: (context, state) {
          return CoachListScreen();
        },
      ),
      GoRoute(
        path: '/team_list',
        builder: (context, state) {
          return TeamListScreen();
        },
      ),
      GoRoute(
        path: '/reusables/edit_player',
        builder: (context, state) {
          return CreatePlayerScreen();
        },
      ),

    ],
    //initialLocation: '/admin_login_screen',
    initialLocation: '/admin_panel',
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