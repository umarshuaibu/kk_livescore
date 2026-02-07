import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kklivescoreadmin/ads/app_open_ad_manager.dart';

import 'package:kklivescoreadmin/fans/home_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  AppOpenAdManager().initialize(); 
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FansApp());
}

class FansApp extends StatelessWidget {
  const FansApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const PublicHomePage(),
        ),

        // Optional: future-safe routes
        // GoRoute(
        //   path: '/league/:leagueId',
        //   builder: (context, state) {
        //     final leagueId = state.pathParameters['leagueId']!;
        //     return LeagueDetailsScreen(leagueId: leagueId);
        //   },
        // ),
      ],
      initialLocation: '/',
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
    );
  } 
}
