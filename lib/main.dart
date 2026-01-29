import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kklivescoreadmin/admins/management/models/player_model.dart';
import 'package:kklivescoreadmin/admins/management/screens/edit_coach_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/edit_player_screen.dart';
import 'package:kklivescoreadmin/admins/management/screens/edit_team_screen.dart';

import 'firebase_options.dart';

// ===== AUTH =====
import 'admins/auth_screen.dart';

// ===== ADMIN CORE =====
import 'admins/app_manager/admin_panel.dart';

// ===== MANAGEMENT =====
import 'admins/management/screens/create_team_screen.dart';
import 'admins/management/screens/create_player_screen.dart';
import 'admins/management/screens/create_coach_screen.dart';
import 'admins/management/screens/player_list_screen.dart';
import 'admins/management/screens/team_list_screen.dart';
import 'admins/management/screens/coach_list_screen.dart';
import 'admins/management/screens/player_transfer_screen.dart';
import 'admins/management/screens/transfer_list_screen.dart';

// ===== LEAGUE =====
import 'league_manager/create_league_screen.dart';
import 'league_manager/league_list_screen.dart';
import 'league_manager/live_updater/match_selector_screen.dart';

// ===== PUBLIC =====
import 'fans/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      debugLogDiagnostics: true,

      refreshListenable: GoRouterRefreshStream(
        _auth.authStateChanges(),
      ),

      // 🔐 AUTH REDIRECT
      redirect: (context, state) {
        final user = _auth.currentUser;
        final isLoggingIn = state.matchedLocation == '/admin_login';

        const publicRoutes = ['/public_test'];

        if (publicRoutes.contains(state.matchedLocation)) {
          return null;
        }

        if (user == null) {
          return isLoggingIn ? null : '/admin_login';
        }

        if (isLoggingIn) {
          return '/admin_panel';
        }

        return null;
      },

      initialLocation: '/admin_panel',

      routes: [
        // ===== AUTH =====
        GoRoute(
          path: '/admin_login',
          builder: (context, state) => const AuthScreen(),
        ),

        // ===== DASHBOARD ROOT =====
        GoRoute(
          path: '/admin_panel',
          builder: (context, state) => const DashboardPage(),
        ),

        // ===== TEAM =====
        GoRoute(
          path: '/create_team',
          builder: (context, state) => const CreateTeamScreen(),
        ),
        GoRoute(
          path: '/team_list',
          builder: (context, state) => TeamListScreen(),
        ),
GoRoute(
  path: '/edit_team/:teamId', // add path param
  builder: (context, state) {
    final teamId = state.pathParameters['teamId']!;
    return EditTeamScreen(teamId: teamId);
  },
),

        // ===== PLAYER =====
        GoRoute(
          path: '/create_player',
          builder: (context, state) => CreatePlayerScreen(
            onDone: () {
              context.go('/player_list');
            },
          ),
        ),

GoRoute(
  path: '/edit_player',
  builder: (context, state) {
    final playerId = state.extra as String;

    return EditPlayerScreen(
      playerId: playerId,
      onDone: () => context.go('/player_list'),
    );
  },
),

// COACH
GoRoute(
  path: '/edit_coach/:coachId', // add path param
  builder: (context, state) {
    final coachId = state.pathParameters['coachId']!;
    return EditCoachScreen(coachId: coachId);
  },
),


        GoRoute(
          path: '/player_list',
          builder: (context, state) => PlayerListScreen(
           onNavigate: (view, {player}) {
              // Intentionally empty.
              // Body navigation is handled by AdminPanel.
            },
          ),
        ),

        // ===== TRANSFER =====
        GoRoute(
          path: '/create_transfer',
          builder: (context, state) => const PlayerTransferScreen(),
        ),
        GoRoute(
          path: '/transfer_list',
          builder: (context, state) => TransferListScreen(),
        ),

        // ===== COACH =====
        GoRoute(
          path: '/create_coach',
          builder: (context, state) => const CreateCoachScreen(),
        ),
        GoRoute(
          path: '/coach_list',
          builder: (context, state) => CoachListScreen(),
        ),

        // ===== LEAGUE =====
        GoRoute(
          path: '/create_league',
          builder: (context, state) => const CreateLeagueScreen(),
        ),
        GoRoute(
          path: '/leagues_list',
          builder: (context, state) => const LeagueListScreen(),
        ),

        // ===== LIVE UPDATER =====
        GoRoute(
          path: '/live_updater/match_selector',
          builder: (context, state) => const MatchSelectorScreen(),
        ),

        // ===== PUBLIC =====
        GoRoute(
          path: '/public_test',
          builder: (context, state) => const PublicHomePage(),
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}

/// 🔁 Refresh GoRouter on auth changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
