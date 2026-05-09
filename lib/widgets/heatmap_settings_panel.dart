import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';

/// Settings panel for controlling heatmap visualization
class HeatmapSettingsPanel extends StatefulWidget {
  final bool showHeatmap;
  final double opacity;
  final String selectedTimeRange;
  final int pointCount;
  final Map<String, dynamic> statistics;
  final Function(bool) onShowHeatmapChanged;
  final Function(double) onOpacityChanged;
  final Function(String) onTimeRangeChanged;

  const HeatmapSettingsPanel({
    super.key,
    required this.showHeatmap,
    required this.opacity,
    required this.selectedTimeRange,
    required this.pointCount,
    required this.statistics,
    required this.onShowHeatmapChanged,
    required this.onOpacityChanged,
    required this.onTimeRangeChanged,
  });

  @override
  State<HeatmapSettingsPanel> createState() => _HeatmapSettingsPanelState();
}

class _HeatmapSettingsPanelState extends State<HeatmapSettingsPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = ThemeHelper.getCardColor(context);
    final textColor = ThemeHelper.getTextColor(context);
    final secondaryTextColor = ThemeHelper.getSecondaryTextColor(context);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (always visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Heatmap icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.showHeatmap 
                          ? AppTheme.highNoise.withValues(alpha: 0.2)
                          : secondaryTextColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.showHeatmap ? Icons.terrain : Icons.terrain_outlined,
                      color: widget.showHeatmap 
                          ? AppTheme.highNoise
                          : secondaryTextColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Heatmap Overlay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.pointCount} points • ${widget.selectedTimeRange}',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand/collapse indicator
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Divider
                  Divider(color: secondaryTextColor.withValues(alpha: 0.1)),
                  
                  // Toggle switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Show Heatmap',
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Visualize noise intensity',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                    value: widget.showHeatmap,
                    onChanged: widget.onShowHeatmapChanged,
                    activeThumbColor: AppTheme.highNoise,
                  ),

                  // Opacity slider (only if heatmap is enabled)
                  if (widget.showHeatmap) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Opacity: ${(widget.opacity * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                    Slider(
                      value: widget.opacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      activeColor: AppTheme.highNoise,
                      onChanged: widget.onOpacityChanged,
                    ),
                  ],

                  // Divider
                  if (widget.showHeatmap)
                    Divider(color: secondaryTextColor.withValues(alpha: 0.1)),

                  // Time range chips
                  if (widget.showHeatmap) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Time Range',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTimeChip('1 Hour'),
                        _buildTimeChip('1 Day'),
                        _buildTimeChip('1 Week'),
                        _buildTimeChip('1 Month'),
                        _buildTimeChip('All Time'),
                      ],
                    ),
                  ],

                  // Statistics (if heatmap is enabled)
                  if (widget.showHeatmap && widget.statistics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Divider(color: secondaryTextColor.withValues(alpha: 0.1)),
                    const SizedBox(height: 8),
                    
                    // Stats grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Avg',
                          '${widget.statistics['avgDb']?.toStringAsFixed(1) ?? '0'} dB',
                          Colors.blue,
                        ),
                        _buildStatItem(
                          'Max',
                          '${widget.statistics['maxDb']?.toStringAsFixed(1) ?? '0'} dB',
                          AppTheme.highNoise,
                        ),
                        _buildStatItem(
                          'Min',
                          '${widget.statistics['minDb']?.toStringAsFixed(1) ?? '0'} dB',
                          AppTheme.lowNoise,
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label) {
    final isSelected = widget.selectedTimeRange == label;
    final isDark = ThemeHelper.isDark(context);

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isSelected ? Colors.white : ThemeHelper.getTextColor(context),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          widget.onTimeRangeChanged(label);
        }
      },
      selectedColor: AppTheme.highNoise,
      backgroundColor: isDark 
          ? ThemeHelper.getBackgroundColor(context).withValues(alpha: 0.5)
          : Colors.grey.shade200,
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: ThemeHelper.getSecondaryTextColor(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
