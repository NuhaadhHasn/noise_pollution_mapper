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
          // Dark mode: White when active, Gray when inactive
          // Light mode: White when active, White with 50% alpha when inactive
          color: isActive
              ? Colors.white
              : (isDark
                    ? AppTheme.textGray
                    : Colors.white.withValues(alpha: 0.5)),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildHomeButton(BuildContext context) {
    final isActive = currentIndex == 2;
    final isDark = ThemeHelper.isDark(context);
    final primaryColor = ThemeHelper.getPrimaryColor(context);

    return GestureDetector(
      onTap: () => onTap(2),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          // Circle background: Primary color in dark mode, White in light mode
          color: isDark ? primaryColor : Colors.white,
          shape: BoxShape.circle,
          // Border: White in dark mode, Primary color in light mode
          border: Border.all(
            color: isActive
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : primaryColor.withValues(alpha: 0.8))
                : (isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : primaryColor.withValues(alpha: 0.5)),
            width: isActive ? 3 : 2,
          ),
          // Shadow: Larger when active
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? primaryColor.withValues(alpha: isActive ? 0.5 : 0.3)
                  : Colors.black.withValues(alpha: isActive ? 0.3 : 0.15),
              blurRadius: isActive ? 12 : 8,
              spreadRadius: isActive ? 2 : 0,
            ),
          ],
        ),
        // Icon: White in dark mode, Primary color in light mode
        child: Icon(
          Icons.home,
          color: isDark ? Colors.white : primaryColor,
          size: 28,
        ),
      ),
    );
  }
}
