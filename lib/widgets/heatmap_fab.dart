import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';

/// Simple FAB button for heatmap toggle
/// No settings panel - just toggle on/off
class HeatmapFab extends StatelessWidget {
  final bool showHeatmap;
  final VoidCallback onTap;

  const HeatmapFab({
    super.key,
    required this.showHeatmap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);

    return FloatingActionButton(
      heroTag: 'heatmap_btn',
      backgroundColor: showHeatmap
          ? AppTheme.highNoise
          : (isDark ? ThemeHelper.getCardColor(context) : Colors.white),
      elevation: showHeatmap ? 6 : 4,
      onPressed: onTap,
      child: Icon(
        Icons.terrain,
        color: showHeatmap ? Colors.white : AppTheme.highNoise,
        size: 24,
      ),
    );
  }
}
