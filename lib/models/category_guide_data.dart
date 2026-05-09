import 'package:flutter/material.dart';
import '../services/yamnet_class_mapping.dart';

/// Data model for Sound Classification Guide
/// Contains information about each sound category for user education
/// 
/// NOTE: This includes all 17 categories defined in YAMNetClassMapping
class CategoryGuideData {
  final String category;
  final IconData icon;
  final int color;
  final List<String> examples;
  final String description;
  final String yamnetInfo;

  CategoryGuideData({
    required this.category,
    required this.icon,
    required this.color,
    required this.examples,
    required this.description,
    required this.yamnetInfo,
  });

  /// Get all category guide data (17 categories total)
  static List<CategoryGuideData> getAllCategories() {
    return [
      // 1. Traffic - Red
      CategoryGuideData(
        category: YAMNetClassMapping.categoryTraffic,
        icon: Icons.traffic,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryTraffic),
        examples: [
          'Cars, buses, and trucks',
          'Motorcycles',
          'Vehicle horns',
          'Engine noise',
        ],
        description: 'Vehicle noise from roads and traffic.',
        yamnetInfo: '40+ vehicle-related YAMNet classes mapped',
      ),

      // 2. Tuk-tuk - Orange
      CategoryGuideData(
        category: YAMNetClassMapping.categoryTuktuk,
        icon: Icons.two_wheeler,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryTuktuk),
        examples: [
          'Three-wheeler engines (Sri Lanka specific)',
          'Scooters and mopeds',
          'Small motorcycle engines',
        ],
        description: 'Three-wheeler and small engine vehicles common in Sri Lanka.',
        yamnetInfo: 'Mapped from motorcycle/scooter YAMNet classes',
      ),

      // 3. Construction - Deep Orange
      CategoryGuideData(
        category: YAMNetClassMapping.categoryConstruction,
        icon: Icons.construction,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryConstruction),
        examples: [
          'Drilling and hammering',
          'Heavy machinery',
          'Sawing and grinding',
          'Construction site noise',
        ],
        description: 'Noise from construction sites and building activities.',
        yamnetInfo: '20+ tool and machinery YAMNet classes mapped',
      ),

      // 4. Industrial - Brown
      CategoryGuideData(
        category: YAMNetClassMapping.categoryIndustrial,
        icon: Icons.factory,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryIndustrial),
        examples: [
          'Industrial equipment',
          'Factory machinery',
          'Manufacturing noise',
          'Industrial motors',
        ],
        description: 'Industrial and factory machinery noise.',
        yamnetInfo: '15+ industrial machinery YAMNet classes mapped',
      ),

      // 5. Speech - Blue
      CategoryGuideData(
        category: YAMNetClassMapping.categorySpeech,
        icon: Icons.record_voice_over,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categorySpeech),
        examples: [
          'Talking and conversation',
          'Announcements and speeches',
          'Phone calls',
          'Group discussions',
        ],
        description: 'Human speech including conversations, announcements, and discussions.',
        yamnetInfo: '35+ speech-related YAMNet classes mapped',
      ),

      // 6. Music - Purple
      CategoryGuideData(
        category: YAMNetClassMapping.categoryMusic,
        icon: Icons.music_note,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryMusic),
        examples: [
          'Songs (any genre)',
          'Musical instruments (guitar, piano, drums)',
          'Radio/TV music',
          'Humming or singing',
        ],
        description: 'Musical sounds of any genre, including instruments and vocals.',
        yamnetInfo: '100+ music-related YAMNet classes mapped',
      ),

      // 7. Religious - Yellow
      CategoryGuideData(
        category: YAMNetClassMapping.categoryReligious,
        icon: Icons.auto_stories,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryReligious),
        examples: [
          'Religious chants and mantras',
          'Temple bells',
          'Church bells',
          'Prayer calls',
        ],
        description: 'Religious and spiritual sounds.',
        yamnetInfo: '10+ religious sound YAMNet classes mapped',
      ),

      // 8. Market - Cyan
      CategoryGuideData(
        category: YAMNetClassMapping.categoryMarket,
        icon: Icons.storefront,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryMarket),
        examples: [
          'Crowd noise',
          'Market vendors',
          'Shopping areas',
          'Street vendors',
        ],
        description: 'Market and commercial area sounds.',
        yamnetInfo: '15+ market and crowd YAMNet classes mapped',
      ),

      // 9. Nature - Green
      CategoryGuideData(
        category: YAMNetClassMapping.categoryNature,
        icon: Icons.park,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryNature),
        examples: [
          'Birds chirping',
          'Wind and rustling leaves',
          'Rain and thunder',
          'Water streams and waves',
          'Animal sounds (pets, farm, wildlife)',
        ],
        description: 'Natural environmental sounds including weather, water, and animals.',
        yamnetInfo: '80+ nature and animal YAMNet classes mapped',
      ),

      // 10. Domestic - Amber
      CategoryGuideData(
        category: YAMNetClassMapping.categoryDomestic,
        icon: Icons.home,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryDomestic),
        examples: [
          'Household appliances',
          'Cleaning sounds',
          'Kitchen activities',
          'Door knocks',
        ],
        description: 'Domestic and household sounds.',
        yamnetInfo: '20+ household sound YAMNet classes mapped',
      ),

      // 11. Alarm - Deep Red
      CategoryGuideData(
        category: YAMNetClassMapping.categoryAlarm,
        icon: Icons.alarm,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryAlarm),
        examples: [
          'Alarm systems',
          'Sirens (emergency vehicles)',
          'Warning signals',
          'Alert tones',
        ],
        description: 'Alarm and warning sounds including emergency sirens.',
        yamnetInfo: '10+ alarm and siren YAMNet classes mapped',
      ),

      // 12. Body Sounds - Lavender
      CategoryGuideData(
        category: YAMNetClassMapping.categoryBodySounds,
        icon: Icons.accessibility_new,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryBodySounds),
        examples: [
          'Cough, sneeze, yawn',
          'Laughing, crying',
          'Breathing, snoring',
          'Heartbeat',
        ],
        description: 'Sounds produced by the human body.',
        yamnetInfo: '15+ body sound YAMNet classes mapped',
      ),

      // 13. Transport - Dark Blue
      CategoryGuideData(
        category: YAMNetClassMapping.categoryTransport,
        icon: Icons.directions_bus,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryTransport),
        examples: [
          'Aircraft (airplanes, helicopters)',
          'Trains and railways',
          'Ships and boats',
          'Public transport',
        ],
        description: 'Transportation sounds including aircraft, trains, and ships.',
        yamnetInfo: '25+ transport YAMNet classes mapped',
      ),

      // 14. Sports - Green (Sports)
      CategoryGuideData(
        category: YAMNetClassMapping.categorySports,
        icon: Icons.sports_soccer,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categorySports),
        examples: [
          'Crowd cheering',
          'Sports equipment (bats, balls)',
          'Whistles (referee)',
          'Stadium noise',
        ],
        description: 'Sports and recreational activity sounds.',
        yamnetInfo: '10+ sports-related YAMNet classes mapped',
      ),

      // 15. Weather - Light Blue
      CategoryGuideData(
        category: YAMNetClassMapping.categoryWeather,
        icon: Icons.cloud,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryWeather),
        examples: [
          'Rain and thunderstorms',
          'Wind and gusts',
          'Hail',
          'Weather phenomena',
        ],
        description: 'Weather and atmospheric sounds.',
        yamnetInfo: '15+ weather-related YAMNet classes mapped',
      ),

      // 16. Office - Deep Purple
      CategoryGuideData(
        category: YAMNetClassMapping.categoryOffice,
        icon: Icons.business,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryOffice),
        examples: [
          'Office equipment (printers, copiers)',
          'Keyboard typing',
          'Phone ringing',
          'Office ambience',
        ],
        description: 'Office and workplace sounds.',
        yamnetInfo: '10+ office-related YAMNet classes mapped',
      ),

      // 17. Other - Grey
      CategoryGuideData(
        category: YAMNetClassMapping.categoryOther,
        icon: Icons.help_outline,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryOther),
        examples: [
          'Finger snap, clapping',
          'Unclassified sounds',
          'Background noise',
          'Static and hiss',
        ],
        description: 'Sounds that do not fit into other categories or are unclassified.',
        yamnetInfo: 'Remaining unmapped YAMNet classes',
      ),
    ];
  }

  /// Get category data by name
  static CategoryGuideData? getCategoryByName(String name) {
    final categories = getAllCategories();
    try {
      return categories.firstWhere((c) => c.category == name);
    } catch (e) {
      return null;
    }
  }
}
