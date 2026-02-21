import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Start animation
    _animationController.forward();

    // Navigate after 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sound Wave Icon
              _buildSoundWaveIcon(),

              const SizedBox(height: 40),

              // App Title
              Text(
                'Noise Mapper',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Visualize your sound environment',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textGray,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom Sound Wave Icon Widget
  Widget _buildSoundWaveIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: ThemeHelper.getPrimaryColor(context).withValues(alpha:0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildSoundBar(40, ThemeHelper.getPrimaryColor(context)),
            const SizedBox(width: 8),
            _buildSoundBar(60, AppTheme.lightPurple),
            const SizedBox(width: 8),
            _buildSoundBar(40, ThemeHelper.getPrimaryColor(context)),
          ],
        ),
      ),
    );
  }

  // Individual sound bar
  Widget _buildSoundBar(double height, Color color) {
    return Container(
      width: 6,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
