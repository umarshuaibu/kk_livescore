import 'package:flutter/material.dart';
import 'package:kklivescoreadmin/admins/management/reusables/constants.dart';
import 'package:kklivescoreadmin/constants/colors.dart';

/// A modern custom progress indicator with sophisticated animations.
class CustomProgressIndicator extends StatefulWidget {
  /// The size of the loading indicator (default is 60x60).
  final double size;

  /// Custom color for the indicator (defaults to primary color).
  final Color? color;

  /// Show loading text or not
  final bool showText;

  const CustomProgressIndicator({
    super.key,
    this.size = 60,
    this.color,
    this.showText = false,
  });

  @override
  State<CustomProgressIndicator> createState() =>
      _CustomProgressIndicatorState();
}

class _CustomProgressIndicatorState extends State<CustomProgressIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Rotation animation (continuous spinning outer ring)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );

    // Pulse animation (breathing effect on opacity)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primaryColor2;

    return widget.showText
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIndicator(color),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _pulseAnimation.value,
                    child: Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ],
          )
        : _buildIndicator(color);
  }

  Widget _buildIndicator(Color color) {
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer rotating ring
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Middle pulsing ring
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: widget.size * 0.7,
                  height: widget.size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(_pulseAnimation.value * 0.5),
                      width: 1.5,
                    ),
                  ),
                );
              },
            ),

            // Inner rotating arc
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_rotationAnimation.value * 2 * 3.14159,
                  child: SizedBox(
                    width: widget.size * 0.6,
                    height: widget.size * 0.6,
                    child: CustomPaint(
                      painter: _ArcPainter(color),
                    ),
                  ),
                );
              },
            ),

            // Center glowing dot
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(_pulseAnimation.value * 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the rotating arc
class _ArcPainter extends CustomPainter {
  final Color color;

  _ArcPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw a small arc (about 1/3 of circle)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2.0,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}