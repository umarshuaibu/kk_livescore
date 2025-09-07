import 'package:flutter/material.dart';

/// A reusable custom progress indicator using the app's logo with fade animation.
class CustomProgressIndicator extends StatefulWidget {
  /// The size of the logo (default is 60x60).
  final double size;

  const CustomProgressIndicator({super.key, this.size = 60});

  @override
  State<CustomProgressIndicator> createState() => _CustomProgressIndicatorState();
}

class _CustomProgressIndicatorState extends State<CustomProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // 2-second cycle: 1s fade in, 1s fade out
    )..repeat(reverse: true); // Loop with fade in and out
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _opacityAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Image.asset(
              'assets/logo.png',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }
}