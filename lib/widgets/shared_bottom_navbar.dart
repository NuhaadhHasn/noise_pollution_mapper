import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';

class SharedBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const SharedBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.darkPurple
              : ThemeHelper.getPrimaryColor(context),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavButton(context, Icons.map_outlined, 0, isDark),
            _buildNavButton(context, Icons.bar_chart, 1, isDark),
            _buildHomeButton(context),
            _buildNavButton(context, Icons.history, 3, isDark),
            _buildNavButton(context, Icons.settings_outlined, 4, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    IconData icon,
    int index,
    bool isDark,
  ) {
    final isActive = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: isActive
              ? (isDark ? ThemeHelper.getPrimaryColor(context) : Colors.white)
              : (isDark
                    ? AppTheme.textGray
                    : Colors.white.withValues(alpha: 0.7)),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildHomeButton(BuildContext context) {
    final isActive = currentIndex == 2;
    return GestureDetector(
      onTap: () => onTap(2),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isActive
              ? ThemeHelper.getPrimaryColor(context)
              : ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.home, color: Colors.white, size: 28),
      ),
    );
  }
}
