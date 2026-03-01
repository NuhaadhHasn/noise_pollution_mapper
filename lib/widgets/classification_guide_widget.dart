import 'package:flutter/material.dart';
import '../utils/theme_helper.dart';
import '../models/category_guide_data.dart';

/// Reusable widget for displaying a category guide tile
/// Shows category information in an expandable format
class CategoryGuideTile extends StatelessWidget {
  final CategoryGuideData categoryData;

  const CategoryGuideTile({
    super.key,
    required this.categoryData,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      color: ThemeHelper.getCardColor(context),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Color(categoryData.color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            categoryData.icon,
            color: Color(categoryData.color),
            size: 24,
          ),
        ),
        title: Text(
          categoryData.category,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ThemeHelper.getTextColor(context),
          ),
        ),
        subtitle: Text(
          categoryData.description,
          style: TextStyle(
            fontSize: 13,
            color: ThemeHelper.getSecondaryTextColor(context),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          // Examples section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Examples header
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: ThemeHelper.getPrimaryColor(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Examples:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.getTextColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Example list
                ...categoryData.examples.map((example) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              fontSize: 14,
                              color: ThemeHelper.getSecondaryTextColor(context),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              example,
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    ThemeHelper.getSecondaryTextColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 12),

                // YAMNet info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(categoryData.color).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(categoryData.color).withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(categoryData.color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          categoryData.yamnetInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(categoryData.color),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
