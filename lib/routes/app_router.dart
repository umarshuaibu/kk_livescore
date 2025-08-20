import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/role_selection_screen.dart';
import '../screens/league_selection_screen.dart';
import '../screens/login/app_manager_login.dart';
import '../screens/login/live_updater_login.dart';
import '../screens/login/news_broadcaster_login.dart';
import '../screens/signup/app_manager_signup.dart';
import '../screens/signup/live_updater_signup.dart';
import '../screens/signup/news_broadcaster_signup.dart';
import '../screens/dashboard/app_manager_dashboard.dart';

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/league-selection',
        builder: (context, state) {
          final role = state.extra as String;
          return LeagueSelectionScreen(role: role);
        },
      ),
      GoRoute(
        path: '/login/app_manager',
        builder: (context, state) => const AppManagerLoginScreen(),
      ),
      GoRoute(
        path: '/login/live_updater',
        builder: (context, state) {
          final league = state.extra as String;
          return LiveUpdaterLoginScreen(league: league);
        },
      ),
      GoRoute(
        path: '/login/news_broadcaster',
        builder: (context, state) {
          final league = state.extra as String;
          return NewsBroadcasterLoginScreen(league: league);
        },
      ),
      GoRoute(
        path: '/signup/app_manager',
        builder: (context, state) => const AppManagerSignupScreen(),
      ),
      GoRoute(
        path: '/signup/live_updater',
        builder: (context, state) {
          final league = state.extra as String;
          return LiveUpdaterSignupScreen(league: league);
        },
      ),
      GoRoute(
        path: '/signup/news_broadcaster',
        builder: (context, state) {
          final league = state.extra as String;
          return NewsBroadcasterSignupScreen(league: league);
        },
      ),
      GoRoute(
        path: '/dashboard/app_manager',
        builder: (context, state) => const AppManagerDashboard(),
      ),
    ],
  );
}