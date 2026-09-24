import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/theme.dart';

/// Ultra-smooth ambient animated background for Dark Mode
/// Uses the client's official palette (~Tropical Teal, ~Bondi Blue, ~Ocean Mist)
/// to create a soft, breathing glowing aurora mesh in dark mode.
class DarkAmbientBackground extends StatefulWidget {
  final Widget child;

  const DarkAmbientBackground({
    super.key,
    required this.child,
  });

  @override
  State<DarkAmbientBackground> createState() => _DarkAmbientBackgroundState();
}

class _DarkAmbientBackgroundState extends State<DarkAmbientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    if (!isDark) {
      return Container(
        color: AppTheme.backgroundColor(context),
        child: widget.child,
      );
    }

    return Container(
      color: AppTheme.darkBackground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Animated glowing ambient canvas
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AmbientAuroraPainter(progress: _controller.value),
                );
              },
            ),
          ),
          // Content on top
          widget.child,
        ],
      ),
    );
  }
}

class _AmbientAuroraPainter extends CustomPainter {
  final double progress;

  _AmbientAuroraPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final t = progress * 2 * math.pi;

    // Orb 1: Tropical Teal (#34A0A4) floating top-right to center
    final x1 = w * 0.72 + math.sin(t) * (w * 0.18);
    final y1 = h * 0.22 + math.cos(t * 0.8) * (h * 0.12);
    final r1 = w * 0.65;
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.tropicalTeal.withValues(alpha: 0.14),
          AppTheme.tropicalTeal.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x1, y1), radius: r1));
    canvas.drawCircle(Offset(x1, y1), r1, paint1);

    // Orb 2: Bondi Blue (#168AAD) floating bottom-left to center
    final x2 = w * 0.28 + math.cos(t * 0.9) * (w * 0.16);
    final y2 = h * 0.68 + math.sin(t * 1.1) * (h * 0.15);
    final r2 = w * 0.70;
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.bondiBlue.withValues(alpha: 0.12),
          AppTheme.bondiBlue.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x2, y2), radius: r2));
    canvas.drawCircle(Offset(x2, y2), r2, paint2);

    // Orb 3: Ocean Mist (#52B69A) floating middle-right
    final x3 = w * 0.85 + math.sin(t * 1.2) * (w * 0.12);
    final y3 = h * 0.82 + math.cos(t) * (h * 0.10);
    final r3 = w * 0.55;
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.oceanMist.withValues(alpha: 0.10),
          AppTheme.oceanMist.withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(x3, y3), radius: r3));
    canvas.drawCircle(Offset(x3, y3), r3, paint3);
  }

  @override
  bool shouldRepaint(covariant _AmbientAuroraPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
