import 'package:flutter/material.dart';
import 'dart:async';

class FansSplashScreen extends StatefulWidget {
  const FansSplashScreen({super.key});

  @override
  State<FansSplashScreen> createState() => _FansSplashScreenState();
}

class _FansSplashScreenState extends State<FansSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Animation setup (fade in)
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();

    // Navigate to main fans page after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/'); // Your main fans route
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Replace with your desired background color
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Image.asset(
            'assets/splash/splash_screen.png', // Your splash image
            width: 180,
            height: 180,
          ),
        ),
      ),
    );
  }
}
