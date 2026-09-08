/// YAMNet Class Mapping for Noise Pollution Categorization

/// Maps YAMNet's 521 audio classes to custom pollution categories
///
/// Categories (17 total):
/// - Traffic: Cars, vehicles, engines, horns
/// - Tuk-tuk: Three-wheelers (Sri Lankan specific)
/// - Construction: Drilling, jackhammer, power tools
/// - Industrial: Machinery, motors, industrial noise
/// - Speech: Conversation, crowd, human voices
/// - Music: Musical instruments, singing
/// - Religious: Temple bells, adhaan, religious sounds
/// - Market: Street vendors, market sounds
/// - Nature: Birds, wind, rain, insects
/// - Other: Unclassified ambient sounds
/// - Domestic: Household appliances, doors, clocks
/// - Alarm: Fire alarms, smoke detectors, buzzers
/// - Body Sounds: Cough, sneeze, heartbeat, clapping
/// - Transport: Train, aircraft, boat, subway
/// - Sports: Gym, swimming, bowling, playground (NEW)
/// - Weather: Rain, thunder, waves, waterfall (NEW)
/// - Office: Printer, computer, radio, telephone (NEW)
library;

import 'package:flutter/services.dart' show rootBundle;

import '../utils/app_logger.dart';

class YAMNetClassMapping {
  /// Sound pollution categories
  static const String categoryTraffic = "Traffic";
  static const String categoryTuktuk = "Tuk-tuk";
  static const String categoryConstruction = "Construction";
  static const String categoryIndustrial = "Industrial";
  static const String categorySpeech = "Speech";
  static const String categoryMusic = "Music";
  static const String categoryReligious = "Religious";
  static const String categoryMarket = "Market";
  static const String categoryNature = "Nature";
  static const String categoryOther = "Other";
  static const String categoryDomestic = "Domestic";
  static const String categoryAlarm = "Alarm";
  static const String categoryBodySounds = "Body Sounds";
  static const String categoryTransport = "Transport";
  static const String categorySports = "Sports";
  static const String categoryWeather = "Weather";
  static const String categoryOffice = "Office";

  /// Live-display-only pseudo-category for below-threshold classifications.
  /// NEVER persisted to Firestore (see the dashboard save-timer gating).
  static const String categoryUncertain = "Uncertain";

  /// Pollution type classification
  static const String typePollution = "Pollution";
  static const String typeAmbient = "Ambient";

  /// YAMNet class index -> official AudioSet display name.
  ///
  /// Populated from assets/models/yamnet_class_map.csv (the official class
  /// map shipped with the yamnet.tflite model) by [loadOfficialClassMap].
  /// Empty until the load completes. Never hand-edit class names here —
  /// the CSV is the single source of truth (finding ml-1).
  static final Map<int, String> indexToClassName = {};

  /// Number of classes the bundled YAMNet model outputs.
  static const int officialClassCount = 521;

  /// Whether the official class map has been loaded successfully.
  static bool get isClassMapLoaded =>
      indexToClassName.length == officialClassCount;

  /// Loads and parses the official YAMNet class map asset.
  ///
  /// CSV format: `index,mid,display_name` where display_name may be quoted
  /// and contain commas (e.g. `1,/m/0ytgt,"Child speech, kid speaking"`).
  /// Returns true only when all 521 rows parsed. Safe to call repeatedly.
  static Future<bool> loadOfficialClassMap() async {
    if (isClassMapLoaded) return true;

    try {
      final csv =
          await rootBundle.loadString('assets/models/yamnet_class_map.csv');
      final parsed = <int, String>{};
      final lines = csv.split('\n');

      // Skip the header row (i = 1).
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final firstComma = line.indexOf(',');
        final secondComma = line.indexOf(',', firstComma + 1);
        if (firstComma < 0 || secondComma < 0) continue;

        final index = int.tryParse(line.substring(0, firstComma));
        if (index == null) continue;

        var name = line.substring(secondComma + 1);
        if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
          name = name.substring(1, name.length - 1).replaceAll('""', '"');
        }
        parsed[index] = name;
      }

      if (parsed.length != officialClassCount) {
        AppLogger.warning(
            'yamnet_class_map.csv parsed ${parsed.length} classes '
            '(expected $officialClassCount)');
        return false;
      }

      indexToClassName
        ..clear()
        ..addAll(parsed);
      AppLogger.info('Official YAMNet class map loaded (521 classes)');
      return true;
    } catch (e) {
      AppLogger.error('Failed to load yamnet_class_map.csv', e);
      return false;
    }
  }

  /// Map YAMNet class names to our custom categories
  /// Based on YAMNet's AudioSet ontology
  static final Map<String, String> classMapping = {
    // Traffic noise
    'Vehicle': categoryTraffic,
    'Car': categoryTraffic,
    'Motor vehicle (road)': categoryTraffic,
    'Vehicle horn, car horn, honking': categoryTraffic,
    'Car alarm': categoryTraffic,
    'Accelerating, revving, vroom': categoryTraffic,
    'Engine': categoryTraffic,
    'Engine starting': categoryTraffic,
    'Idling': categoryTraffic,
    'Revving': categoryTraffic,
    'Accelerating': categoryTraffic,
    'Traffic noise, roadway noise': categoryTraffic,
    'Truck': categoryTraffic,
    'Bus': categoryTraffic,
    'Tire squeal': categoryTraffic,
    'Skidding': categoryTraffic,
    'Brake': categoryTraffic,

    // Tuk-tuk / Three-wheeler (Sri Lankan specific)
    // YAMNet doesn't have specific tuk-tuk class, map similar sounds
    'Motorcycle': categoryTuktuk,
    'Scooter': categoryTuktuk,
    // 'Motor vehicle (road)': categoryTuktuk, // Duplicate key - already mapped to TRAFFIC
    'Small engine': categoryTuktuk,

    // Construction noise
    'Jackhammer': categoryConstruction,
    'Drill': categoryConstruction,
    'Power tool': categoryConstruction,
    'Sawing': categoryConstruction,
    'Hammer': categoryConstruction,
    'Hammering': categoryConstruction,
    'Filing (rasp)': categoryConstruction,
    'Sanding': categoryConstruction,
    'Crushing': categoryConstruction,
    'Breaking': categoryConstruction,
    'Boom': categoryConstruction,
    'Bang': categoryConstruction,

    // Industrial noise
    'Machine': categoryIndustrial,
    'Machinery': categoryIndustrial,
    'Industrial noise': categoryIndustrial,
    'Motor': categoryIndustrial,
    'Medium engine (mid frequency)': categoryIndustrial,
    'Light engine (high frequency)': categoryIndustrial,
    'Mechanical fan': categoryIndustrial,
    'Air conditioning': categoryIndustrial,
    'Hum': categoryIndustrial,
    'Whoosh, swoosh, swish': categoryIndustrial,
    'Power windows, electric windows': categoryIndustrial,
    'Chainsaw': categoryIndustrial,
    'Lawn mower': categoryIndustrial,

    // Speech / Conversation
    'Speech': categorySpeech,
    'Male speech, man speaking': categorySpeech,
    'Female speech, woman speaking': categorySpeech,
    'Child speech, kid speaking': categorySpeech,
    'Conversation': categorySpeech,
    'Narration, monologue': categorySpeech,
    'Babbling': categorySpeech,
    'Speech synthesizer': categorySpeech,
    'Shout': categorySpeech,
    'Yell': categorySpeech,
    'Screaming': categorySpeech,
    'Whispering': categorySpeech,
    'Laughter': categorySpeech,
    'Chuckle, chortle': categorySpeech,
    'Belly laugh': categorySpeech,
    'Giggle': categorySpeech,
    'Snicker': categorySpeech,
    'Crowd': categorySpeech,
    'Hubbub, speech noise, speech babble': categorySpeech,
    'Children playing': categorySpeech,
    'Battle cry': categorySpeech,
    'Cheering': categorySpeech,
    'Applause': categorySpeech,
    // Human body sounds
    'Breathing': categoryBodySounds,
    'Gasp': categoryBodySounds,
    'Cough': categoryBodySounds,
    'Throat clearing': categoryBodySounds,
    'Sneeze': categoryBodySounds,
    'Sniff': categoryBodySounds,
    'Clapping': categoryBodySounds,
    'Finger snapping': categoryBodySounds,
    'Hands': categoryBodySounds,
    'Heart sounds, heartbeat': categoryBodySounds,
    'Chewing, mastication': categoryBodySounds,
    'Biting': categoryBodySounds,
    'Gargling': categoryBodySounds,
    'Stomach rumble': categoryBodySounds,
    'Burping, eructation': categoryBodySounds,
    'Hiccup': categoryBodySounds,
    'Fart': categoryBodySounds,
    'Shuffle': categoryBodySounds,

    // Music
    'Music': categoryMusic,
    'Musical instrument': categoryMusic,
    'Plucked string instrument': categoryMusic,
    'Guitar': categoryMusic,
    'Bass guitar': categoryMusic,
    'Acoustic guitar': categoryMusic,
    'Electric guitar': categoryMusic,
    'Steel guitar, slide guitar': categoryMusic,
    'Tapping (guitar technique)': categoryMusic,
    'Strum': categoryMusic,
    'Banjo': categoryMusic,
    'Sitar': categoryMusic,
    'Mandolin': categoryMusic,
    'Ukulele': categoryMusic,
    'String instrument': categoryMusic,
    'Violin, fiddle': categoryMusic,
    'Cello': categoryMusic,
    'Double bass': categoryMusic,
    'Harp': categoryMusic,
    'Keyboard (musical)': categoryMusic,
    'Piano': categoryMusic,
    'Electric piano': categoryMusic,
    'Organ': categoryMusic,
    'Synthesizer': categoryMusic,
    'Accordion': categoryMusic,
    'Harmonica': categoryMusic,
    'Wind instrument, woodwind instrument': categoryMusic,
    'Saxophone': categoryMusic,
    'Clarinet': categoryMusic,
    'Brass instrument': categoryMusic,
    'Trumpet': categoryMusic,
    'Trombone': categoryMusic,
    'French horn': categoryMusic,
    'Tuba': categoryMusic,
    'Drum': categoryMusic,
    'Drum kit': categoryMusic,
    'Bass drum': categoryMusic,
    'Snare drum': categoryMusic,
    'Rimshot': categoryMusic,
    'Cymbal': categoryMusic,
    'Hi-hat': categoryMusic,
    'Percussion': categoryMusic,
    'Tambourine': categoryMusic,
    'Cowbell (instrument)': categoryMusic,
    'Tuning fork': categoryMusic,
    'Marimba, xylophone': categoryMusic,
    'Rattle (instrument)': categoryMusic,
    'Singing': categoryMusic,
    'Song': categoryMusic,
    'Jingle, tinkle': categoryMusic,
    'Tabla': categoryMusic,
    'Flute': categoryMusic,
    // Music genres
    'Music genre': categoryMusic,
    'Rock music': categoryMusic,
    'Heavy metal': categoryMusic,
    'Punk rock': categoryMusic,
    'Grunge': categoryMusic,
    'Progressive rock': categoryMusic,
    'Rock and roll': categoryMusic,
    'Psychedelic rock': categoryMusic,
    'Rhythm and blues': categoryMusic,
    'Soul music': categoryMusic,
    'Funk': categoryMusic,
    'Disco': categoryMusic,
    'Pop music': categoryMusic,
    'Hip hop music': categoryMusic,
    'Rapping': categoryMusic,
    'Electronic music': categoryMusic,
    'House music': categoryMusic,
    'Techno': categoryMusic,
    'Dubstep': categoryMusic,
    'Drum and bass': categoryMusic,
    'Electronic dance music': categoryMusic,
    'Trance music': categoryMusic,
    'Music of Latin America': categoryMusic,
    'Salsa music': categoryMusic,
    'Reggae': categoryMusic,
    'Country music': categoryMusic,
    'Jazz': categoryMusic,
    'Swing music': categoryMusic,
    'Bluegrass': categoryMusic,
    'Classical music': categoryMusic,
    'Opera': categoryMusic,
    'Choir': categoryMusic,
    'Traditional music': categoryMusic,
    'Middle Eastern music': categoryMusic,
    'Carnatic music': categoryMusic,
    'Music of Bollywood': categoryMusic,
    // Vocals and other music
    'Vocal music': categoryMusic,
    'Jingle (music)': categoryMusic,
    'Humming': categoryMusic,
    'Yodeling': categoryMusic,

    // Religious sounds
    'Bell': categoryReligious,
    'Church bell': categoryReligious,
    'Jingle bell': categoryReligious,
    'Chime': categoryReligious,
    'Gong': categoryReligious,
    'Singing bowl': categoryReligious,
    'Prayer': categoryReligious,
    'Chant': categoryReligious,
    'Mantra': categoryReligious,

    // Market / Street vendors (human activity sounds)
    // 'Crowd': categoryMarket, // Duplicate key - already mapped to SPEECH
    // 'Hubbub, speech noise, speech babble': categoryMarket, // Duplicate key - already mapped to SPEECH
    'Busy signal': categoryDomestic,
    'Squeak': categoryDomestic,
    'Walk, footsteps': categoryBodySounds,
    'Run': categoryBodySounds,
    'Shuffling cards': categoryDomestic,

    // Domestic/Household sounds
    'Domestic sounds, home sounds': categoryDomestic,
    'Door': categoryDomestic,
    'Doorbell': categoryDomestic,
    'Knock': categoryDomestic,
    'Slam': categoryDomestic,
    'Dishes, pots, and pans': categoryDomestic,
    'Cutlery, silverware': categoryDomestic,
    'Chopping (food)': categoryDomestic,
    'Frying (food)': categoryDomestic,
    'Microwave oven': categoryDomestic,
    'Blender': categoryDomestic,
    'Water tap, faucet': categoryDomestic,
    'Sink (filling or washing)': categoryDomestic,
    'Bathtub (filling or washing)': categoryDomestic,
    'Hair dryer': categoryDomestic,
    'Toilet flush': categoryDomestic,
    'Electric toothbrush': categoryDomestic,
    'Vacuum cleaner': categoryDomestic,
    'Zipper (clothing)': categoryDomestic,
    'Keys jangling': categoryDomestic,
    'Coin (dropping)': categoryDomestic,
    'Scissors': categoryDomestic,
    'Electric shaver, electric razor': categoryDomestic,
    'Typing': categoryDomestic,
    'Typewriter': categoryDomestic,
    'Computer keyboard': categoryDomestic,
    'Writing': categoryDomestic,
    'Mechanical pencil': categoryDomestic,
    'Cupboard open or close': categoryDomestic,
    'Drawer open or close': categoryDomestic,
    'Creak': categoryDomestic,
    'Clock': categoryDomestic,
    'Tick': categoryDomestic,
    'Tick-tock': categoryDomestic,
    'Alarm clock': categoryAlarm,
    'Clock alarm': categoryAlarm,
    'Telephone': categoryDomestic,
    'Telephone bell ringing': categoryDomestic,
    'Ringtone': categoryDomestic,
    'Telephone dialing, DTMF': categoryDomestic,
    'Dial tone': categoryDomestic,

    // Emergency/Alert sounds (Traffic category for visibility)
    'Siren': categoryTraffic,
    'Civil defense siren': categoryAlarm,
    'Buzzer': categoryAlarm,
    'Smoke detector, smoke alarm': categoryAlarm,
    'Fire alarm': categoryAlarm,
    'Foghorn': categoryTransport,
    'Emergency vehicle': categoryTraffic,
    'Police car (siren)': categoryTraffic,
    'Ambulance (siren)': categoryTraffic,
    'Fire engine, fire truck (siren)': categoryTraffic,
    'Air horn, truck horn': categoryTraffic,
    'Reversing beeps': categoryTraffic,
    'Steam whistle': categoryTransport,
    'Whistle': categoryOther,

    // More transportation
    'Train': categoryTransport,
    'Train whistle': categoryTransport,
    'Train horn': categoryTransport,
    'Railroad car, train wagon': categoryTransport,
    'Train wheels squealing': categoryTransport,
    'Subway, metro, underground': categoryTransport,
    'Aircraft': categoryTransport,
    'Aircraft engine': categoryTransport,
    'Jet engine': categoryTransport,
    'Propeller, airscrew': categoryTransport,
    'Helicopter': categoryTransport,
    'Fixed-wing aircraft, airplane': categoryTransport,
    'Bicycle': categoryTransport,
    'Bicycle bell': categoryTransport,
    'Skateboard': categoryTransport,
    'Car passing by': categoryTraffic,
    'Race car, auto racing': categoryTraffic,
    'Auto rickshaw': categoryTuktuk,
    'Go-kart': categoryTuktuk,

    // Environmental/room-tone sounds (official AudioSet names)
    'Environmental noise': categoryOther,
    'Reverberation': categoryOther,
    'Echo': categoryOther,
    
    // Field recording (official AudioSet name, index 520)
    'Field recording': categoryNature,

    // Nature / Ambient
    'Bird': categoryNature,
    'Bird vocalization, bird call, bird song': categoryNature,
    'Chirp, tweet': categoryNature,
    'Squawk': categoryNature,
    'Pigeon, dove': categoryNature,
    'Coo': categoryNature,
    'Crow': categoryNature,
    'Caw': categoryNature,
    'Owl': categoryNature,
    'Hoot': categoryNature,
    'Animal': categoryNature,
    'Domestic animals, pets': categoryNature,
    'Dog': categoryNature,
    'Bark': categoryNature,
    'Yip': categoryNature,
    'Howl': categoryNature,
    'Growling': categoryNature,
    'Cat': categoryNature,
    'Meow': categoryNature,
    'Purr': categoryNature,
    'Hiss (cat)': categoryNature,
    'Livestock, farm animals, working animals': categoryNature,
    'Horse': categoryNature,
    'Neigh, whinny': categoryNature,
    'Cattle, bovinae': categoryNature,
    'Moo': categoryNature,
    'Cowbell': categoryNature,
    'Pig': categoryNature,
    'Oink': categoryNature,
    'Goat': categoryNature,
    'Bleat': categoryNature,
    'Sheep': categoryNature,
    'Fowl': categoryNature,
    'Chicken, rooster': categoryNature,
    'Cluck': categoryNature,
    'Crowing, cock-a-doodle-doo': categoryNature,
    'Turkey': categoryNature,
    'Gobble': categoryNature,
    'Duck': categoryNature,
    'Quack': categoryNature,
    'Goose': categoryNature,
    'Honk': categoryNature,
    'Frog': categoryNature,
    'Croak': categoryNature,
    'Wind': categoryWeather,
    'Wind noise (microphone)': categoryWeather,
    'Rustling leaves': categoryNature,
    'Wind chime': categoryNature,
    'Rain': categoryWeather,
    'Raindrop': categoryWeather,
    'Rain on surface': categoryWeather,
    'Thunder': categoryWeather,
    'Thunderstorm': categoryWeather,
    'Lightning': categoryWeather,
    'Breeze': categoryWeather,
    'Gust': categoryWeather,
    'Water': categoryNature,
    'Stream': categoryNature,
    'Waterfall': categoryNature,
    'Ocean': categoryNature,
    'Waves, surf': categoryNature,
    'Gurgling': categoryNature,
    'Fire': categoryNature,
    'Crackle': categoryNature,
    'Roaring': categoryNature,
    'Insect': categoryNature,
    'Cricket': categoryNature,
    'Mosquito': categoryNature,
    'Fly, housefly': categoryNature,
    'Buzz': categoryNature,
    'Bee, wasp, etc.': categoryNature,
    'Snake': categoryNature,
    'Rattle': categoryNature,
    'Whale vocalization': categoryNature,
    'Environmental sounds': categoryNature,
    'Rustle': categoryNature,
    'Bow-wow': categoryNature,
    'Bay': categoryNature,
    'Clip-clop': categoryNature,

    // Sports and recreation — only 'Basketball bounce' (official index 459)
    // maps directly; everything else reaches Sports via keyword fallback
    // in _categorizeByKeywords or via manual reports.
    'Basketball bounce': categorySports,

    // Office and technology (official AudioSet names only:
    // indices 408 Cash register, 409 Printer, 410-411 cameras, 519 Radio)
    'Printer': categoryOffice,
    'Radio': categoryOffice,
    'Cash register': categoryOffice,
    'Camera': categoryOffice,
    'Single-lens reflex camera': categoryOffice,

    // ── Official AudioSet names previously unmapped (ml-1 re-audit) ──
    // Human voice (crying/laughing family stays with Speech, matching
    // the existing 'Laughter' -> Speech decision)
    'Bellow': categorySpeech,
    'Whoop': categorySpeech,
    'Children shouting': categorySpeech,
    'Baby laughter': categorySpeech,
    'Crying, sobbing': categorySpeech,
    'Baby cry, infant cry': categorySpeech,
    'Whimper': categorySpeech,
    'Wail, moan': categorySpeech,
    'Sigh': categorySpeech,
    'Groan': categorySpeech,
    'Grunt': categorySpeech,
    'Chatter': categorySpeech,
    // Body sounds
    'Whistling': categoryBodySounds,
    'Wheeze': categoryBodySounds,
    'Snoring': categoryBodySounds,
    'Pant': categoryBodySounds,
    'Snort': categoryBodySounds,
    'Heart murmur': categoryBodySounds,
    // Animals / nature
    'Wild animals': categoryNature,
    'Roaring cats (lions, tigers)': categoryNature,
    'Roar': categoryNature,
    'Canidae, dogs, wolves': categoryNature,
    'Rodents, rats, mice': categoryNature,
    'Mouse': categoryNature,
    'Patter': categoryNature,
    'Bird flight, flapping wings': categoryNature,
    'Caterwaul': categoryNature,
    'Whimper (dog)': categoryNature,
    'Steam': categoryNature,
    'Outside, rural or natural': categoryNature,
    // Water vehicles / rail
    'Boat, Water vehicle': categoryTransport,
    'Sailboat, sailing ship': categoryTransport,
    'Rowboat, canoe, kayak': categoryTransport,
    'Motorboat, speedboat': categoryTransport,
    'Ship': categoryTransport,
    'Rail transport': categoryTransport,
    // Road vehicles
    'Air brake': categoryTraffic,
    'Ice cream truck, ice cream van': categoryTraffic,
    'Toot': categoryTraffic,
    'Heavy engine (low frequency)': categoryTraffic,
    'Engine knocking': categoryTraffic,
    // Impulsive/percussive noise — Construction, consistent with the
    // existing 'Boom'/'Bang' mapping and the explosion/firework keyword rule
    "Dental drill, dentist's drill": categoryConstruction,
    'Tools': categoryConstruction,
    'Explosion': categoryConstruction,
    'Gunshot, gunfire': categoryConstruction,
    'Machine gun': categoryConstruction,
    'Fusillade': categoryConstruction,
    'Artillery fire': categoryConstruction,
    'Cap gun': categoryConstruction,
    'Fireworks': categoryConstruction,
    'Firecracker': categoryConstruction,
    'Burst, pop': categoryConstruction,
    'Eruption': categoryConstruction,
    // Mechanisms
    'Mechanisms': categoryIndustrial,
    'Ratchet, pawl': categoryIndustrial,
    'Gears': categoryIndustrial,
    'Pulleys': categoryIndustrial,
    'Mains hum': categoryIndustrial,
    'Sewing machine': categoryDomestic,
    'Television': categoryDomestic,
    // Alarms — without an exact entry, official 'Alarm' (index 382) would
    // partial-match 'Car alarm' and be misfiled under Traffic
    'Alarm': categoryAlarm,
    'Beep, bleep': categoryAlarm,
    // Room/environment tones (very common argmaxes in real recordings)
    'Inside, small room': categoryOther,
    'Inside, large room or hall': categoryOther,
    'Inside, public space': categoryOther,
    'Outside, urban or manmade': categoryOther,
    'Noise': categoryOther,
    'Cacophony': categoryOther,
    'Distortion': categoryOther,
    'Sidetone': categoryOther,
    'Throbbing': categoryOther,
    'Vibration': categoryOther,
    'Sine wave': categoryOther,
    'Harmonic': categoryOther,
    'Chirp tone': categoryOther,
    'Sound effect': categoryOther,
    'Pulse': categoryOther,

    // Other / Ambient
    'Silence': categoryOther,
    'White noise': categoryOther,
    'Pink noise': categoryOther,
    'Static': categoryOther,
    'Hiss': categoryOther,
    'Pop': categoryOther,
    'Crack': categoryOther,
    'Crunch': categoryOther,
    'Whir': categoryOther,
    'Clang': categoryOther,
    'Thump': categoryOther,
    'Ambient music': categoryMusic,
  };

  /// Determine if a sound category is considered pollution or ambient
  static String getSoundType(String category) {
    switch (category) {
      case categoryTraffic:
      case categoryTuktuk:
      case categoryConstruction:
      case categoryIndustrial:
        return typePollution;

      case categoryTransport:
      case categoryAlarm:
        return typePollution;

      case categorySpeech:
      case categoryMusic:
      case categoryReligious:
      case categoryMarket:
      case categoryNature:
      case categoryOther:
      case categoryDomestic:
      case categoryBodySounds:
      case categorySports:
      case categoryWeather:
      case categoryOffice:
      case categoryUncertain:
        return typeAmbient;

      default:
        return typeAmbient;
    }
  }

  /// Single source of truth for bucketing a `soundClass` value AS STORED in
  /// Firestore into Pollution/Ambient. Handles the two manual-report values
  /// from report_noise_screen.dart ('Speech-Pollution'/'Speech-Ambient')
  /// that are not YAMNet categories, then defers to [getSoundType].
  /// Use this everywhere instead of hand-maintained category lists
  /// (findings flow3-8 / analytics-4).
  static String soundTypeForStoredClass(String storedClass) {
    if (storedClass == 'Speech-Pollution') return typePollution;
    if (storedClass == 'Speech-Ambient') return typeAmbient;
    return getSoundType(storedClass);
  }

  /// Get category from YAMNet class name or index
  static String getCategoryFromClassName(String className) {
    String? actualClassName;
    int? classIndex;

    // Check if className is in format "YAMNet_Class_123"
    if (className.startsWith('YAMNet_Class_')) {
      final indexStr = className.replaceFirst('YAMNet_Class_', '');
      classIndex = int.tryParse(indexStr);

      if (classIndex != null && indexToClassName.containsKey(classIndex)) {
        // Convert index to AudioSet class name
        actualClassName = indexToClassName[classIndex]!;
      } else {
        // Unknown class index - try intelligent categorization by keywords
        return _categorizeByKeywords(className, classIndex);
      }
    } else {
      actualClassName = className;
    }

    // Try exact match first
    if (classMapping.containsKey(actualClassName)) {
      return classMapping[actualClassName]!;
    }

    // Try partial match (case insensitive)
    final lowerClassName = actualClassName.toLowerCase();

    for (var entry in classMapping.entries) {
      if (lowerClassName.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerClassName)) {
        return entry.value;
      }
    }

    // Try intelligent categorization by keywords
    return _categorizeByKeywords(actualClassName, classIndex);
  }

  /// Intelligent categorization for unmapped classes based on keywords
  static String _categorizeByKeywords(String className, int? classIndex) {
    final lower = className.toLowerCase();

    // Range-based fallback for "YAMNet_Class_N" placeholders (only produced
    // when the official class map failed to load). Coarse buckets follow the
    // OFFICIAL yamnet_class_map.csv ordering, verified against the CSV:
    // 0 Speech..35 Whistling, 36 Breathing..60 Heart murmur,
    // 61 Cheering..66 Children playing, 67 Animal..131 Whale vocalization,
    // 132 Music..276 Scary music, 277 Wind..281 Thunder, 282 Water..293
    // Crackle, 294 Vehicle..321 Traffic noise, 322 Rail transport..336
    // Skateboard, 337 Engine..347 Accelerating, 348 Door..388 Busy signal,
    // 389 Alarm clock..395 Foghorn, 406 Fan/407 A/C, 408 Cash register..412
    // Tools, 413 Hammer..430 Boom. Everything else: Other.
    if (classIndex != null && className.startsWith('YAMNet_Class_')) {
      if (classIndex >= 0 && classIndex <= 34) return categorySpeech;
      if (classIndex >= 35 && classIndex <= 60) return categoryBodySounds;
      if (classIndex >= 61 && classIndex <= 66) return categorySpeech;
      if (classIndex >= 67 && classIndex <= 131) return categoryNature;
      if (classIndex >= 132 && classIndex <= 276) return categoryMusic;
      if (classIndex >= 277 && classIndex <= 281) return categoryWeather;
      if (classIndex >= 282 && classIndex <= 293) return categoryNature;
      if (classIndex >= 294 && classIndex <= 321) return categoryTraffic;
      if (classIndex >= 322 && classIndex <= 336) return categoryTransport;
      if (classIndex >= 337 && classIndex <= 347) return categoryTraffic;
      if (classIndex >= 348 && classIndex <= 388) return categoryDomestic;
      if (classIndex >= 389 && classIndex <= 395) return categoryAlarm;
      if (classIndex >= 406 && classIndex <= 407) return categoryIndustrial;
      if (classIndex >= 408 && classIndex <= 412) return categoryOffice;
      if (classIndex >= 413 && classIndex <= 430) return categoryConstruction;
      return categoryOther;
    }

    // Transport keywords (train, aircraft — checked before general Traffic)
    if (lower.contains('train') ||
        lower.contains('railway') ||
        lower.contains('railroad') ||
        lower.contains('subway') ||
        lower.contains('metro') ||
        lower.contains('aircraft') ||
        lower.contains('airplane') ||
        lower.contains('helicopter') ||
        lower.contains('jet') ||
        lower.contains('propeller') ||
        lower.contains('boat') ||
        lower.contains('ship') ||
        lower.contains('vessel') ||
        lower.contains('ferry') ||
        lower.contains('foghorn')) {
      return categoryTransport;
    }

    // Traffic/Vehicle keywords
    if (lower.contains('vehicle') ||
        lower.contains('car') ||
        lower.contains('truck') ||
        lower.contains('bus') ||
        lower.contains('traffic') ||
        lower.contains('engine') ||
        lower.contains('motor') ||
        lower.contains('horn') ||
        lower.contains('brake') ||
        lower.contains('tire') ||
        lower.contains('accelerat')) {
      return categoryTraffic;
    }

    // Motorcycle/Scooter keywords (Tuk-tuk)
    if (lower.contains('motorcycle') ||
        lower.contains('scooter') ||
        lower.contains('moped') ||
        lower.contains('bike')) {
      return categoryTuktuk;
    }

    // Music keywords
    if (lower.contains('music') ||
        lower.contains('instrument') ||
        lower.contains('piano') ||
        lower.contains('guitar') ||
        lower.contains('drum') ||
        lower.contains('sing') ||
        lower.contains('vocal') ||
        lower.contains('melody') ||
        lower.contains('song') ||
        lower.contains('orchestra') ||
        lower.contains('band') ||
        lower.contains('rhythm') ||
        lower.contains('beat') ||
        lower.contains('bass') ||
        lower.contains('treble') ||
        lower.contains('harmony') ||
        lower.contains('trumpet') ||
        lower.contains('violin') ||
        lower.contains('saxophone') ||
        lower.contains('flute') ||
        lower.contains('organ') ||
        lower.contains('keyboard') ||
        lower.contains('synthesizer') ||
        lower.contains('harp') ||
        lower.contains('cello') ||
        lower.contains('tuba') ||
        lower.contains('clarinet') ||
        lower.contains('rock') ||
        lower.contains('pop') ||
        lower.contains('jazz') ||
        lower.contains('classical') ||
        lower.contains('hip hop') ||
        lower.contains('electronic') ||
        lower.contains('techno') ||
        lower.contains('disco') ||
        lower.contains('reggae') ||
        lower.contains('country') ||
        lower.contains('opera') ||
        lower.contains('choir') ||
        lower.contains('tambourine') ||
        lower.contains('marimba') ||
        lower.contains('xylophone') ||
        lower.contains('percussion') ||
        lower.contains('accordion') ||
        lower.contains('harmonica') ||
        lower.contains('trombone') ||
        lower.contains('rapping') ||
        lower.contains('humming') ||
        lower.contains('yodel') ||
        lower.contains('bluegrass') ||
        lower.contains('dubstep') ||
        lower.contains('trance') ||
        lower.contains('salsa') ||
        lower.contains('carnatic') ||
        lower.contains('ukulele') ||
        lower.contains('mandolin') ||
        lower.contains('banjo') ||
        lower.contains('sitar') ||
        lower.contains('tabla') ||
        lower.contains('lullaby')) {
      return categoryMusic;
    }

    // Body sounds keywords (checked before general Speech)
    if (lower.contains('cough') ||
        lower.contains('sneeze') ||
        lower.contains('breathing') ||
        lower.contains('breath') ||
        lower.contains('heartbeat') ||
        lower.contains('sniff') ||
        lower.contains('gasp') ||
        lower.contains('throat') ||
        lower.contains('clap') ||
        lower.contains('snapping') ||
        lower.contains('footstep') ||
        lower.contains('chewing') ||
        lower.contains('chew') ||
        lower.contains('burping') ||
        lower.contains('burp') ||
        lower.contains('hiccup') ||
        lower.contains('gargling') ||
        lower.contains('stomach')) {
      return categoryBodySounds;
    }

    // Speech keywords
    if (lower.contains('speech') ||
        lower.contains('speak') ||
        lower.contains('talk') ||
        lower.contains('voice') ||
        lower.contains('conversation') ||
        lower.contains('narrat') ||
        lower.contains('male') ||
        lower.contains('female') ||
        lower.contains('child') ||
        lower.contains('laugh') ||
        lower.contains('shout') ||
        lower.contains('yell') ||
        lower.contains('whisper') ||
        lower.contains('crowd') ||
        lower.contains('cheer') ||
        lower.contains('applause') ||
        lower.contains('human') ||
        lower.contains('giggle') ||
        lower.contains('snicker')) {
      return categorySpeech;
    }

    // Alarm keywords
    if (lower.contains('alarm') ||
        lower.contains('smoke detector') ||
        lower.contains('fire alarm') ||
        lower.contains('buzzer') ||
        lower.contains('notification') ||
        lower.contains('alert') ||
        lower.contains('warning signal')) {
      return categoryAlarm;
    }

    // Construction keywords
    if (lower.contains('jackhammer') ||
        lower.contains('drill') ||
        lower.contains('saw') ||
        lower.contains('hammer') ||
        lower.contains('construction') ||
        lower.contains('demolit') ||
        lower.contains('breaking') ||
        lower.contains('crushing') ||
        lower.contains('boom') ||
        lower.contains('bang') ||
        lower.contains('explosion') ||
        lower.contains('blast') ||
        lower.contains('firework')) {
      return categoryConstruction;
    }

    // Industrial keywords
    if (lower.contains('machine') ||
        lower.contains('machinery') ||
        lower.contains('industrial') ||
        lower.contains('factory') ||
        lower.contains('pump') ||
        lower.contains('fan') ||
        lower.contains('air conditioning') ||
        lower.contains('hum') ||
        lower.contains('chainsaw') ||
        lower.contains('mower') ||
        lower.contains('compressor') ||
        lower.contains('grinder') ||
        lower.contains('boiler') ||
        lower.contains('diesel')) {
      return categoryIndustrial;
    }

    // Domestic / Household keywords
    if (lower.contains('door') ||
        lower.contains('appliance') ||
        lower.contains('kitchen') ||
        lower.contains('household') ||
        lower.contains('domestic') ||
        lower.contains('fridge') ||
        lower.contains('refrigerator') ||
        lower.contains('microwave') ||
        lower.contains('blender') ||
        lower.contains('vacuum') ||
        lower.contains('toilet') ||
        lower.contains('faucet') ||
        lower.contains('telephone') ||
        lower.contains('ringtone') ||
        lower.contains('typing') ||
        lower.contains('keyboard') ||
        lower.contains('clock') ||
        lower.contains('dishwasher') ||
        lower.contains('washing machine') ||
        lower.contains('oven') ||
        lower.contains('toaster') ||
        lower.contains('cupboard') ||
        lower.contains('drawer') ||
        lower.contains('creak')) {
      return categoryDomestic;
    }

    // Religious keywords
    if (lower.contains('bell') ||
        lower.contains('church') ||
        lower.contains('chime') ||
        lower.contains('gong') ||
        lower.contains('prayer') ||
        lower.contains('chant') ||
        lower.contains('hymn') ||
        lower.contains('religious')) {
      return categoryReligious;
    }

    // Weather keywords — checked BEFORE Nature so rain/wind/thunder route here
    if (lower.contains('rain') ||
        lower.contains('raindrop') ||
        lower.contains('thunder') ||
        lower.contains('storm') ||
        lower.contains('lightning') ||
        lower.contains('wind') ||
        lower.contains('breeze') ||
        lower.contains('gust')) {
      return categoryWeather;
    }

    // Nature keywords
    if (lower.contains('bird') ||
        lower.contains('animal') ||
        lower.contains('dog') ||
        lower.contains('cat') ||
        lower.contains('water') ||
        lower.contains('nature') ||
        lower.contains('chirp') ||
        lower.contains('bark') ||
        lower.contains('meow') ||
        lower.contains('pet') ||
        lower.contains('livestock') ||
        lower.contains('horse') ||
        lower.contains('cattle') ||
        lower.contains('cow') ||
        lower.contains('pig') ||
        lower.contains('goat') ||
        lower.contains('sheep') ||
        lower.contains('chicken') ||
        lower.contains('rooster') ||
        lower.contains('duck') ||
        lower.contains('goose') ||
        lower.contains('pigeon') ||
        lower.contains('crow') ||
        lower.contains('owl') ||
        lower.contains('insect') ||
        lower.contains('cricket') ||
        lower.contains('mosquito') ||
        lower.contains('bee') ||
        lower.contains('wasp') ||
        lower.contains('frog') ||
        lower.contains('snake') ||
        lower.contains('whale') ||
        lower.contains('ocean') ||
        lower.contains('stream') ||
        lower.contains('waterfall') ||
        lower.contains('wave') ||
        lower.contains('fire') ||
        lower.contains('leaves') ||
        lower.contains('rustle') ||
        lower.contains('bow-wow') ||
        lower.contains('clip-clop') ||
        lower.contains('environmental')) {
      return categoryNature;
    }

    // Market/Crowd keywords
    if (lower.contains('market') ||
        lower.contains('bazaar') ||
        lower.contains('busy') ||
        lower.contains('bustling') ||
        lower.contains('crowded')) {
      return categoryMarket;
    }

    // Sports keywords (NEW)
    if (lower.contains('gym') ||
        lower.contains('sport') ||
        lower.contains('weight') ||
        lower.contains('exercise') ||
        lower.contains('aerobics') ||
        lower.contains('yoga') ||
        lower.contains('stretch') ||
        lower.contains('run') ||
        lower.contains('jog') ||
        lower.contains('treadmill') ||
        lower.contains('bowl') ||
        lower.contains('billiard') ||
        lower.contains('pool') ||
        lower.contains('swim') ||
        lower.contains('dive') ||
        lower.contains('playground') ||
        lower.contains('stadium') ||
        lower.contains('cheer') ||
        lower.contains('boo') ||
        lower.contains('whistle (referee)') ||
        lower.contains('referee') ||
        lower.contains('skate') ||
        lower.contains('surf') ||
        lower.contains('snowboard') ||
        lower.contains('ski') ||
        lower.contains('rollerblad') ||
        lower.contains('cycle') ||
        lower.contains('bike') ||
        lower.contains('climb') ||
        lower.contains('martial') ||
        lower.contains('box') ||
        lower.contains('wrestl') ||
        lower.contains('fence')) {
      return categorySports;
    }

    // Body sounds keywords (NEW)
    if (lower.contains('whistle') ||
        lower.contains('mouth whistle')) {
      return categoryBodySounds;
    }

    // Transport keywords (NEW)
    if (lower.contains('bicycle') ||
        lower.contains('bike') ||
        lower.contains('skateboard') ||
        lower.contains('steam whistle')) {
      return categoryTransport;
    }

    // Office keywords (NEW)
    if (lower.contains('printer') ||
        lower.contains('copier') ||
        lower.contains('scanner') ||
        lower.contains('fax') ||
        lower.contains('computer') ||
        lower.contains('office') ||
        lower.contains('keyboard') ||
        lower.contains('mouse') ||
        lower.contains('cubicle') ||
        lower.contains('meeting') ||
        lower.contains('conference') ||
        lower.contains('radio') ||
        lower.contains('broadcast') ||
        lower.contains('podcast') ||
        lower.contains('news') ||
        lower.contains('talk show') ||
        lower.contains('telephone') ||
        lower.contains('answering') ||
        lower.contains('voicemail') ||
        lower.contains('cash register') ||
        lower.contains('atm') ||
        lower.contains('barcode') ||
        lower.contains('calculator') ||
        lower.contains('projector') ||
        lower.contains('whiteboard') ||
        lower.contains('shredder') ||
        lower.contains('stapler')) {
      return categoryOffice;
    }

    // Default to OTHER if no match found
    return categoryOther;
  }

  /// Get emoji icon for category (for UI display)
  static String getCategoryIcon(String category) {
    switch (category) {
      case categoryTraffic:
        return '🚗';
      case categoryTuktuk:
        return '🛺';
      case categoryConstruction:
        return '🏗️';
      case categoryIndustrial:
        return '🏭';
      case categorySpeech:
        return '🗣️';
      case categoryMusic:
        return '🎵';
      case categoryReligious:
        return '🔔';
      case categoryMarket:
        return '🏪';
      case categoryNature:
        return '🌿';
      case categoryDomestic:
        return '🏠';
      case categoryAlarm:
        return '🚨';
      case categoryBodySounds:
        return '👤';
      case categoryTransport:
        return '🚆';
      case categorySports:
        return '⚽';
      case categoryWeather:
        return '🌦️';
      case categoryOffice:
        return '💼';
      case categoryUncertain:
        return '❓';
      case categoryOther:
      default:
        return '🔊';
    }
  }

  /// Get color for category (for UI display)
  static int getCategoryColor(String category) {
    switch (category) {
      case categoryTraffic:
        return 0xFFF44336; // Red
      case categoryTuktuk:
        return 0xFFFF9800; // Orange
      case categoryConstruction:
        return 0xFFFF5722; // Deep Orange
      case categoryIndustrial:
        return 0xFF795548; // Brown
      case categorySpeech:
        return 0xFF2196F3; // Blue
      case categoryMusic:
        return 0xFF9C27B0; // Purple
      case categoryReligious:
        return 0xFFFFEB3B; // Yellow
      case categoryMarket:
        return 0xFF00BCD4; // Cyan
      case categoryNature:
        return 0xFF4CAF50; // Green
      case categoryDomestic:
        return 0xFFFFB300; // Amber
      case categoryAlarm:
        return 0xFFC62828; // Deep Red
      case categoryBodySounds:
        return 0xFF9575CD; // Lavender
      case categoryTransport:
        return 0xFF1565C0; // Dark Blue
      case categorySports:
        return 0xFF43A047; // Green (sports)
      case categoryWeather:
        return 0xFF039BE5; // Light Blue (weather)
      case categoryOffice:
        return 0xFF5E35B1; // Deep Purple (office)
      case categoryUncertain:
        return 0xFF757575; // Dark Grey (uncertain)
      case categoryOther:
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}
