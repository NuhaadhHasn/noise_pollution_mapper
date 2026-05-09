import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';

class DecibelMeterGauge extends StatelessWidget {
  final double currentDb;
  final double maxDb;

  const DecibelMeterGauge({
    super.key,
    required this.currentDb,
    this.maxDb = 100,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        children: [
          // Gauge (background, arc, tick marks, numbers)
          CustomPaint(
            size: const Size(320, 320),
            painter: DecibelGaugePainter(currentDb: currentDb, maxDb: maxDb, isDark: isDark),
          ),
          // Digital number - positioned carefully
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Text(
                    currentDb.toStringAsFixed(0),
                    style: TextStyle(
                      color: isDark ? AppTheme.textWhite : AppTheme.textDark,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // dB label stays at normal position
                Text(
                  'dB',
                  style: TextStyle(
                    color: isDark ? AppTheme.textGray : AppTheme.textLightGray,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          // Needle (on top!)
          CustomPaint(
            size: const Size(320, 320),
            painter: NeedlePainter(currentDb: currentDb, maxDb: maxDb, isDark: isDark),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the circular gauge
class DecibelGaugePainter extends CustomPainter {
  final double currentDb;
  final double maxDb;
  final bool isDark;

  DecibelGaugePainter({required this.currentDb, required this.maxDb, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 40;

    // Background circle - theme-aware
    final bgPaint = Paint()
      ..color = isDark ? AppTheme.cardBackground : AppTheme.lightCardBackground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          AppTheme.primaryPurple,
          AppTheme.lightPurple,
          _getDbColor(currentDb),
        ],
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    // Calculate progress (0 to 270 degrees)
    final progress = (currentDb / maxDb).clamp(0.0, 1.0);
    final sweepAngle = progress * (3 / 2 * math.pi);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );

    // Draw tick marks and numbers
    _drawTickMarksAndNumbers(canvas, center, radius, size);
    // Note: Needle is now drawn in separate NeedlePainter for proper layering
  }

  void _drawTickMarksAndNumbers(
    Canvas canvas,
    Offset center,
    double radius,
    Size size,
  ) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw ticks and numbers for 0, 25, 50, 75, 100
    for (int db = 0; db <= 100; db += 25) {
      final progress = db / 100;
      final angle = -math.pi / 2 + progress * (3 / 2 * math.pi);

      // Draw tick mark
      final tickPaint = Paint()
        ..color = isDark ? AppTheme.textWhite.withValues(alpha: 0.6) : AppTheme.textDark.withValues(alpha: 0.6)
        ..strokeWidth = 3;

      final tickStart = Offset(
        center.dx + (radius - 15) * math.cos(angle),
        center.dy + (radius - 15) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + (radius + 5) * math.cos(angle),
        center.dy + (radius + 5) * math.sin(angle),
      );

      canvas.drawLine(tickStart, tickEnd, tickPaint);

      // Draw numbers
      textPainter.text = TextSpan(
        text: '$db',
        style: TextStyle(
          color: isDark ? AppTheme.textGray : AppTheme.textLightGray,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();

      final textX =
          center.dx + (radius + 25) * math.cos(angle) - textPainter.width / 2;
      final textY =
          center.dy + (radius + 25) * math.sin(angle) - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  // Get color based on dB level
  Color _getDbColor(double db) {
    if (db < 50) {
      return AppTheme.lowNoise; // Green - safe
    } else if (db < 70) {
      return AppTheme.moderateNoise; // Orange - moderate
    } else {
      return AppTheme.highNoise; // Red - dangerous
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Separate painter for NEEDLE ONLY (drawn on top)
class NeedlePainter extends CustomPainter {
  final double currentDb;
  final double maxDb;
  final bool isDark;

  NeedlePainter({required this.currentDb, required this.maxDb, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 40;
    final progress = (currentDb / maxDb).clamp(0.0, 1.0);
    final needleAngle = -math.pi / 2 + progress * (3 / 2 * math.pi);

    // Draw needle - LONGER to match bigger gauge
    final needlePaint = Paint()
      ..color = AppTheme.primaryPurple
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final needleEnd = Offset(
      center.dx + (radius - 5) * math.cos(needleAngle),
      center.dy + (radius - 5) * math.sin(needleAngle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);

    // Needle center dot (purple)
    final dotPaint = Paint()
      ..color = AppTheme.primaryPurple
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 10, dotPaint);

    // White center dot - theme-aware
    final whiteDotPaint = Paint()
      ..color = isDark ? AppTheme.textWhite : AppTheme.textDark
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 5, whiteDotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
