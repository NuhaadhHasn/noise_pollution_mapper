import 'package:flutter/material.dart';
import '../utils/theme_helper.dart';
import '../models/category_guide_data.dart';
import '../widgets/classification_guide_widget.dart';

/// Sound Classification Guide Screen
///
/// Displays an interactive guide showing all 17 sound categories
/// with examples, descriptions, and YAMNet mapping information.
class ClassificationGuideScreen extends StatelessWidget {
  const ClassificationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = CategoryGuideData.getAllCategories();
    final isDark = ThemeHelper.isDark(context);

    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Sound Classification Guide'),
        backgroundColor: ThemeHelper.getCardColor(context),
        elevation: 2,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        titleTextStyle: TextStyle(
          color: ThemeHelper.getTextColor(context),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Column(
        children: [
          // Header information
          _buildHeader(context),

          // Categories list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return CategoryGuideTile(
                  categoryData: categories[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build header section with introduction
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeHelper.getPrimaryColor(context),
            ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sound Classification',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '17 Categories',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          const Text(
            'This guide explains what sounds are classified into each category. '
            'Tap on any category to see examples and learn more about how our AI '
            'identifies different types of sounds.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                context,
                Icons.auto_awesome,
                'AI-Powered',
                Colors.white.withValues(alpha: 0.2),
              ),
              _buildInfoChip(
                context,
                Icons.science,
                'YAMNet Model',
                Colors.white.withValues(alpha: 0.2),
              ),
              _buildInfoChip(
                context,
                Icons.category,
                '17 Categories',
                Colors.white.withValues(alpha: 0.2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build info chip widget
  Widget _buildInfoChip(
    BuildContext context,
    IconData icon,
    String label,
    Color backgroundColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
