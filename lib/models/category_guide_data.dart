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
          'Vehicle horns and engine noise',
          'Emergency-vehicle sirens (police, ambulance, fire engine)',
          'Car alarms and reversing beeps',
        ],
        description:
            'Road vehicle noise, including emergency-vehicle sirens.',
        yamnetInfo: '28 official vehicle and siren classes mapped directly',
      ),

      // 2. Tuk-tuk - Orange
      CategoryGuideData(
        category: YAMNetClassMapping.categoryTuktuk,
        icon: Icons.two_wheeler,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryTuktuk),
        examples: [
          'Three-wheeler engines (Sri Lanka specific)',
          'Motorcycles',
          'Small two-stroke engines (keyword-detected)',
        ],
        description:
            'Three-wheeler and small engine vehicles common in Sri Lanka.',
        yamnetInfo:
            "1 official class ('Motorcycle') plus scooter/moped keyword fallback",
      ),

      // 3. Construction - Deep Orange
      CategoryGuideData(
        category: YAMNetClassMapping.categoryConstruction,
        icon: Icons.construction,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryConstruction),
        examples: [
          'Drilling, hammering, and jackhammers',
          'Sawing, sanding, and power tools',
          'Explosions, blasting, and fireworks',
        ],
        description:
            'Construction-site tools and impulsive blast-type noise.',
        yamnetInfo: '23 official tool and impulse-noise classes mapped directly',
      ),

      // 4. Industrial - Brown
      CategoryGuideData(
        category: YAMNetClassMapping.categoryIndustrial,
        icon: Icons.factory,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryIndustrial),
        examples: [
          'Factory machinery, gears, and mechanisms',
          'Fans and air conditioning',
          'Chainsaws and lawn mowers',
          'Electrical mains hum',
        ],
        description: 'Industrial and machinery noise.',
        yamnetInfo: '14 official machinery classes mapped directly',
      ),

      // 5. Speech - Blue
      CategoryGuideData(
        category: YAMNetClassMapping.categorySpeech,
        icon: Icons.record_voice_over,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categorySpeech),
        examples: [
          'Talking and conversation',
          'Shouting, crowds, and chatter',
          'Laughing and crying',
          'Children playing',
        ],
        description:
            'Human voices: conversation, crowds, laughter, and crying.',
        yamnetInfo: '32 official human-voice classes mapped directly',
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
        description:
            'Musical sounds of any genre, including instruments and vocals.',
        yamnetInfo:
            '88 official music classes mapped directly, plus genre keyword fallback',
      ),

      // 7. Religious - Yellow
      CategoryGuideData(
        category: YAMNetClassMapping.categoryReligious,
        icon: Icons.auto_stories,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryReligious),
        examples: [
          'Church and temple bells',
          'Chants and mantras',
          'Gongs and chimes',
        ],
        description: 'Religious and spiritual sounds.',
        yamnetInfo: '8 official bell and chant classes mapped directly',
      ),

      // 8. Market - Cyan
      CategoryGuideData(
        category: YAMNetClassMapping.categoryMarket,
        icon: Icons.storefront,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryMarket),
        examples: [
          'Street market and bazaar ambience (keyword-detected)',
          'Manually reported market noise',
        ],
        description:
            'Market and commercial-area sounds. No YAMNet class maps directly '
            'to Market; crowd sounds are classified as Speech.',
        yamnetInfo: 'Keyword fallback and manual reports only - no direct classes',
      ),

      // 9. Nature - Green
      CategoryGuideData(
        category: YAMNetClassMapping.categoryNature,
        icon: Icons.park,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryNature),
        examples: [
          'Birds, insects, and animals (pets, farm, wildlife)',
          'Water: streams, waterfalls, ocean waves',
          'Rustling leaves and crackling fire',
        ],
        description:
            'Animal and natural-environment sounds. Rain, wind, and thunder '
            'are classified as Weather.',
        yamnetInfo: '78 official animal and nature classes mapped directly',
      ),

      // 10. Domestic - Amber
      CategoryGuideData(
        category: YAMNetClassMapping.categoryDomestic,
        icon: Icons.home,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryDomestic),
        examples: [
          'Doors, knocks, and doorbells',
          'Kitchen and appliance sounds',
          'Telephones, clocks, and television',
        ],
        description: 'Domestic and household sounds.',
        yamnetInfo: '42 official household classes mapped directly',
      ),

      // 11. Alarm - Deep Red
      CategoryGuideData(
        category: YAMNetClassMapping.categoryAlarm,
        icon: Icons.alarm,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryAlarm),
        examples: [
          'Alarm clocks and buzzers',
          'Smoke detectors and fire alarms',
          'Civil defense sirens',
        ],
        description:
            'Alarm and warning sounds. Emergency-vehicle sirens (police, '
            'ambulance, fire engine) are classified as Traffic.',
        yamnetInfo: '7 official alarm classes mapped directly',
      ),

      // 12. Body Sounds - Lavender
      CategoryGuideData(
        category: YAMNetClassMapping.categoryBodySounds,
        icon: Icons.accessibility_new,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryBodySounds),
        examples: [
          'Cough, sneeze, and sniff',
          'Breathing, snoring, and heartbeat',
          'Clapping, finger snapping, and footsteps',
          'Whistling',
        ],
        description:
            'Sounds produced by the human body. Laughing and crying are '
            'classified as Speech.',
        yamnetInfo: '26 official body-sound classes mapped directly',
      ),

      // 13. Transport - Dark Blue
      CategoryGuideData(
        category: YAMNetClassMapping.categoryTransport,
        icon: Icons.directions_bus,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryTransport),
        examples: [
          'Trains, railways, and subways',
          'Aircraft and helicopters',
          'Boats and ships',
          'Bicycles and skateboards',
        ],
        description:
            'Rail, air, and water transport sounds. Buses are classified '
            'as Traffic.',
        yamnetInfo: '23 official transport classes mapped directly',
      ),

      // 14. Sports - Green (Sports)
      CategoryGuideData(
        category: YAMNetClassMapping.categorySports,
        icon: Icons.sports_soccer,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categorySports),
        examples: [
          'Basketball bounce',
          'Gym, stadium, and sports keywords (keyword-detected)',
        ],
        description:
            'Sports and recreation sounds. Mostly keyword-detected or '
            'manually reported.',
        yamnetInfo:
            "1 official class ('Basketball bounce') plus keyword fallback",
      ),

      // 15. Weather - Light Blue
      CategoryGuideData(
        category: YAMNetClassMapping.categoryWeather,
        icon: Icons.cloud,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryWeather),
        examples: [
          'Rain and raindrops',
          'Thunder and thunderstorms',
          'Wind',
        ],
        description: 'Weather and atmospheric sounds.',
        yamnetInfo: '7 official weather classes mapped directly',
      ),

      // 16. Office - Deep Purple
      CategoryGuideData(
        category: YAMNetClassMapping.categoryOffice,
        icon: Icons.business,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryOffice),
        examples: [
          'Printers and cash registers',
          'Radio',
          'Cameras',
        ],
        description: 'Office and workplace sounds.',
        yamnetInfo: '5 official office and technology classes mapped directly',
      ),

      // 17. Other - Grey
      CategoryGuideData(
        category: YAMNetClassMapping.categoryOther,
        icon: Icons.help_outline,
        color: YAMNetClassMapping.getCategoryColor(YAMNetClassMapping.categoryOther),
        examples: [
          'Silence and background noise',
          'Static, white noise, and pink noise',
          'Room tone (indoor/outdoor ambience)',
          'Unclassified sounds',
        ],
        description:
            'Ambient room tone and sounds that do not fit other categories. '
            'Finger snaps and clapping are classified as Body Sounds.',
        yamnetInfo:
            '28 official ambience/noise classes mapped directly, plus all unmatched sounds',
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
