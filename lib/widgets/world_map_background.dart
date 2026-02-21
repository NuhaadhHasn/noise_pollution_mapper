import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WorldMapBackground extends StatelessWidget {
  const WorldMapBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // World map silhouette
        CustomPaint(
          size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
          painter: WorldMapPainter(),
        ),

        // Location pins on major cities
        _buildLocationPins(),
      ],
    );
  }

  Widget _buildLocationPins() {
    return Stack(
      children: [
        // Colombo, Sri Lanka area
        Positioned(
          top: 300,
          left: 200,
          child: _buildLocationPin(),
        ),
        // North America
        Positioned(
          top: 180,
          left: 80,
          child: _buildLocationPin(),
        ),
        // Europe
        Positioned(
          top: 150,
          left: 180,
          child: _buildLocationPin(),
        ),
        // East Asia
        Positioned(
          top: 200,
          right: 80,
          child: _buildLocationPin(),
        ),
        // South America
        Positioned(
          bottom: 200,
          left: 100,
          child: _buildLocationPin(),
        ),
        // Australia
        Positioned(
          bottom: 180,
          right: 70,
          child: _buildLocationPin(),
        ),
      ],
    );
  }

  Widget _buildLocationPin() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: AppTheme.lightPurple,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.lightPurple.withValues(alpha:0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

// Custom painter for world map silhouette
class WorldMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3D3554) // Lighter purple for visibility
      ..style = PaintingStyle.fill;

    // Simplified continent shapes
    // Note: These are very simplified representations for educational purposes

    // North America (simplified)
    _drawNorthAmerica(canvas, size, paint);

    // South America (simplified)
    _drawSouthAmerica(canvas, size, paint);

    // Europe (simplified)
    _drawEurope(canvas, size, paint);

    // Africa (simplified)
    _drawAfrica(canvas, size, paint);

    // Asia (simplified)
    _drawAsia(canvas, size, paint);

    // Australia (simplified)
    _drawAustralia(canvas, size, paint);
  }

  void _drawNorthAmerica(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.15, h * 0.25);
    path.quadraticBezierTo(w * 0.18, h * 0.20, w * 0.22, h * 0.22);
    path.quadraticBezierTo(w * 0.25, h * 0.24, w * 0.28, h * 0.30);
    path.lineTo(w * 0.26, h * 0.40);
    path.quadraticBezierTo(w * 0.20, h * 0.42, w * 0.15, h * 0.38);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawSouthAmerica(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.25, h * 0.50);
    path.lineTo(w * 0.28, h * 0.48);
    path.quadraticBezierTo(w * 0.30, h * 0.55, w * 0.28, h * 0.65);
    path.quadraticBezierTo(w * 0.24, h * 0.68, w * 0.22, h * 0.62);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawEurope(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.48, h * 0.22);
    path.quadraticBezierTo(w * 0.52, h * 0.20, w * 0.55, h * 0.23);
    path.lineTo(w * 0.54, h * 0.28);
    path.quadraticBezierTo(w * 0.50, h * 0.30, w * 0.47, h * 0.27);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawAfrica(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.48, h * 0.32);
    path.quadraticBezierTo(w * 0.52, h * 0.30, w * 0.56, h * 0.35);
    path.lineTo(w * 0.55, h * 0.50);
    path.quadraticBezierTo(w * 0.50, h * 0.55, w * 0.46, h * 0.50);
    path.lineTo(w * 0.47, h * 0.35);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawAsia(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.58, h * 0.20);
    path.quadraticBezierTo(w * 0.68, h * 0.18, w * 0.75, h * 0.22);
    path.lineTo(w * 0.78, h * 0.35);
    path.quadraticBezierTo(w * 0.72, h * 0.42, w * 0.65, h * 0.40);
    path.lineTo(w * 0.60, h * 0.35);
    path.quadraticBezierTo(w * 0.56, h * 0.28, w * 0.58, h * 0.20);
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawAustralia(Canvas canvas, Size size, Paint paint) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.70, h * 0.60);
    path.quadraticBezierTo(w * 0.75, h * 0.58, w * 0.78, h * 0.62);
    path.lineTo(w * 0.76, h * 0.68);
    path.quadraticBezierTo(w * 0.72, h * 0.70, w * 0.68, h * 0.66);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
