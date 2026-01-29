import 'package:flutter/material.dart';

class GlobalVariables {
  static GlobalKey<ScaffoldState> homeScaffoldKey = GlobalKey();
  static RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  static GlobalKey<NavigatorState> navigatorKey =
      GlobalKey(debugLabel: "Main Navigator");
}