import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/constants/global_veriables.dart';

/// ------------------------------------------------------------
/// SAFE SCREEN SIZE GETTERS
/// ------------------------------------------------------------

double _fallbackWidth = 375; // default design width
double _fallbackHeight = 812; // default design height

BuildContext? get _ctx => GlobalVariables.navigatorKey.currentContext;

double get kScreenWidth {
  final ctx = _ctx;
  if (ctx == null) return _fallbackWidth;
  return MediaQuery.sizeOf(ctx).width;
}

double get kScreenHeight {
  final ctx = _ctx;
  if (ctx == null) return _fallbackHeight;
  return MediaQuery.sizeOf(ctx).height;
}

/// ------------------------------------------------------------
/// SPACING WIDGETS
/// ------------------------------------------------------------

class VerticalSpacing extends StatelessWidget {
  const VerticalSpacing(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: value);
  }
}

class HorizontalSpacing extends StatelessWidget {
  const HorizontalSpacing(this.value, {super.key});
  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: value);
  }
}

/// ------------------------------------------------------------
/// RESPONSIVE SIZE HELPERS
/// ------------------------------------------------------------

// Design height reference: 672.83
double eqH(double inDesign) =>
    (inDesign / 672.83) * kScreenHeight;

// Design width reference: 328.53
double eqW(double inDesign) =>
    (inDesign / 328.53) * kScreenWidth;

/// ------------------------------------------------------------
/// PADDING HELPER
/// ------------------------------------------------------------

EdgeInsetsGeometry pad({
  double horiz = 0,
  double vert = 0,
  double? both,
}) =>
    EdgeInsets.symmetric(
      horizontal: eqW(both ?? horiz),
      vertical: eqH(both ?? vert),
    );

/// ------------------------------------------------------------
/// DIRECT WIDTH ACCESS (SAFE)
/// ------------------------------------------------------------

double width(BuildContext context) =>
    MediaQuery.of(context).size.width;

/// ------------------------------------------------------------
/// COMMON CONSTANTS
/// ------------------------------------------------------------

double get screenPadding => eqW(14.02);
