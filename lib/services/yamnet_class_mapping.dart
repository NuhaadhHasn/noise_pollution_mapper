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

  /// Pollution type classification
  static const String typePollution = "Pollution";
  static const String typeAmbient = "Ambient";

  /// YAMNet AudioSet class index to name mapping
  /// Maps class indices (0-520) to AudioSet class names
  /// Source: YAMNet AudioSet ontology
  static final Map<int, String> indexToClassName = {
    // Speech and human sounds
    0: 'Speech',
    1: 'Male speech, man speaking',
    2: 'Female speech, woman speaking',
    3: 'Child speech, kid speaking',
    4: 'Conversation',
    5: 'Narration, monologue',
    6: 'Babbling',
    7: 'Speech synthesizer',
    8: 'Shout',
    9: 'Screaming',
    10: 'Whispering',
    11: 'Laughter',
    12: 'Chuckle, chortle',
    13: 'Belly laugh',
    14: 'Giggle',
    15: 'Snicker',
    16: 'Breathing',
    17: 'Gasp',
    18: 'Cough',
    19: 'Throat clearing',
    20: 'Sneeze',
    21: 'Sniff',
    22: 'Run',
    23: 'Shuffle',
    24: 'Walk, footsteps',
    25: 'Chewing, mastication',
    26: 'Biting',
    27: 'Gargling',
    28: 'Stomach rumble',
    29: 'Burping, eructation',
    30: 'Hiccup',
    31: 'Fart',
    32: 'Hands',
    33: 'Finger snapping',
    34: 'Clapping',
    35: 'Heart sounds, heartbeat',

    // Music and genres
    137: 'Music',
    138: 'Musical instrument',
    139: 'Piano',
    140: 'Electric piano',
    141: 'Organ',
    142: 'Synthesizer',
    143: 'Guitar',
    144: 'Acoustic guitar',
    145: 'Drum',
    146: 'Drum kit',
    147: 'Bass drum',
    148: 'Snare drum',
    149: 'Rimshot',
    150: 'Cymbal',
    151: 'Hi-hat',
    152: 'Tabla',
    153: 'Bass guitar',
    154: 'Electric guitar',
    155: 'Steel guitar, slide guitar',
    156: 'Tapping (guitar technique)',
    157: 'Strum',
    158: 'Banjo',
    159: 'Sitar',
    160: 'Mandolin',
    161: 'Ukulele',
    162: 'Keyboard (musical)',
    163: 'Accordion',
    164: 'Harmonica',
    165: 'Wind instrument, woodwind instrument',
    166: 'Flute',
    167: 'Saxophone',
    168: 'Clarinet',
    169: 'Brass instrument',
    170: 'Trumpet',
    171: 'Trombone',
    172: 'French horn',
    173: 'Tuba',
    174: 'String instrument',
    175: 'Violin, fiddle',
    176: 'Cello',
    177: 'Double bass',
    178: 'Harp',
    179: 'Percussion',
    180: 'Cowbell (instrument)',
    181: 'Tambourine',
    182: 'Rattle (instrument)',
    183: 'Marimba, xylophone',
    184: 'Music genre',
    185: 'Rock music',
    186: 'Heavy metal',
    187: 'Punk rock',
    188: 'Grunge',
    189: 'Progressive rock',
    190: 'Rock and roll',
    191: 'Psychedelic rock',
    192: 'Rhythm and blues',
    193: 'Soul music',
    194: 'Funk',
    195: 'Disco',
    196: 'Pop music',
    197: 'Hip hop music',
    198: 'Rapping',
    199: 'Electronic music',
    200: 'House music',
    201: 'Techno',
    202: 'Dubstep',
    203: 'Drum and bass',
    204: 'Electronic dance music',
    205: 'Ambient music',
    206: 'Trance music',
    207: 'Music of Latin America',
    208: 'Salsa music',
    209: 'Reggae',
    210: 'Country music',
    211: 'Jazz',
    212: 'Swing music',
    213: 'Bluegrass',
    214: 'Classical music',
    215: 'Opera',
    216: 'Choir',
    217: 'Traditional music',
    218: 'Middle Eastern music',
    219: 'Carnatic music',
    220: 'Music of Bollywood',
    221: 'Singing',
    222: 'Vocal music',
    223: 'Song',
    224: 'Jingle (music)',
    225: 'Humming',
    226: 'Yodeling',
    227: 'Chant',
    228: 'Mantra',

    // Traffic and vehicles
    310: 'Vehicle',
    311: 'Car',
    312: 'Motor vehicle (road)',
    313: 'Vehicle horn, car horn, honking',
    314: 'Car alarm',
    315: 'Accelerating, revving, vroom',
    316: 'Engine',
    317: 'Engine starting',
    318: 'Traffic noise, roadway noise',
    319: 'Truck',
    320: 'Bus',
    321: 'Motorcycle',
    322: 'Scooter',

    // Construction
    388: 'Jackhammer',
    389: 'Drill',
    390: 'Power tool',
    391: 'Sawing',
    392: 'Hammer',
    393: 'Hammering',

    // Industrial
    394: 'Machine',
    395: 'Machinery',
    396: 'Industrial noise',
    397: 'Motor',
    398: 'Medium engine (mid frequency)',
    399: 'Light engine (high frequency)',

    // Nature and Animals
    36: 'Domestic animals, pets',
    37: 'Dog',
    38: 'Bark',
    39: 'Yip',
    40: 'Howl',
    41: 'Bow-wow',
    42: 'Growling',
    43: 'Bay',
    44: 'Cat',
    45: 'Meow',
    46: 'Purr',
    47: 'Hiss (cat)',
    48: 'Livestock, farm animals, working animals',
    49: 'Horse',
    50: 'Clip-clop',
    51: 'Neigh, whinny',
    52: 'Cattle, bovinae',
    53: 'Moo',
    54: 'Cowbell',
    55: 'Pig',
    56: 'Oink',
    57: 'Goat',
    58: 'Bleat',
    59: 'Sheep',
    60: 'Fowl',
    61: 'Chicken, rooster',
    62: 'Cluck',
    63: 'Crowing, cock-a-doodle-doo',
    64: 'Turkey',
    65: 'Gobble',
    66: 'Duck',
    67: 'Quack',
    68: 'Goose',
    69: 'Honk',
    70: 'Bird',
    71: 'Bird vocalization, bird call, bird song',
    72: 'Chirp, tweet',
    73: 'Squawk',
    74: 'Pigeon, dove',
    75: 'Coo',
    76: 'Crow',
    77: 'Caw',
    78: 'Owl',
    79: 'Hoot',
    80: 'Insect',
    81: 'Cricket',
    82: 'Mosquito',
    83: 'Fly, housefly',
    84: 'Buzz',
    85: 'Bee, wasp, etc.',
    86: 'Frog',
    87: 'Croak',
    88: 'Snake',
    89: 'Rattle',
    90: 'Whale vocalization',
    91: 'Environmental sounds',
    92: 'Wind',
    93: 'Rustling leaves',
    94: 'Wind chime',
    95: 'Rain',
    96: 'Rain on surface',
    97: 'Raindrop',
    98: 'Thunder',
    99: 'Thunderstorm',
    100: 'Water',
    101: 'Stream',
    102: 'Waterfall',
    103: 'Ocean',
    104: 'Waves, surf',
    105: 'Gurgling',
    106: 'Fire',
    107: 'Crackle',
    108: 'Roaring',

    // Domestic and household sounds
    229: 'Domestic sounds, home sounds',
    230: 'Door',
    231: 'Doorbell',
    232: 'Knock',
    233: 'Slam',
    234: 'Squeak',
    235: 'Cupboard open or close',
    236: 'Drawer open or close',
    237: 'Dishes, pots, and pans',
    238: 'Cutlery, silverware',
    239: 'Chopping (food)',
    240: 'Frying (food)',
    241: 'Microwave oven',
    242: 'Blender',
    243: 'Water tap, faucet',
    244: 'Sink (filling or washing)',
    245: 'Bathtub (filling or washing)',
    246: 'Hair dryer',
    247: 'Toilet flush',
    248: 'Electric toothbrush',
    249: 'Vacuum cleaner',
    250: 'Zipper (clothing)',
    251: 'Keys jangling',
    252: 'Coin (dropping)',
    253: 'Scissors',
    254: 'Electric shaver, electric razor',
    255: 'Shuffling cards',
    256: 'Typing',
    257: 'Typewriter',
    258: 'Computer keyboard',
    259: 'Writing',
    260: 'Mechanical pencil',
    261: 'Scissors',
    262: 'Alarm',
    263: 'Clock',
    264: 'Tick',
    265: 'Tick-tock',
    266: 'Alarm clock',
    267: 'Clock alarm',
    268: 'Telephone',
    269: 'Telephone bell ringing',
    270: 'Ringtone',
    271: 'Telephone dialing, DTMF',
    272: 'Dial tone',
    273: 'Busy signal',

    // More vehicles and traffic
    274: 'Siren',
    275: 'Civil defense siren',
    276: 'Buzzer',
    277: 'Smoke detector, smoke alarm',
    278: 'Fire alarm',
    279: 'Foghorn',
    280: 'Whistle',
    281: 'Steam whistle',
    282: 'Emergency vehicle',
    283: 'Police car (siren)',
    284: 'Ambulance (siren)',
    285: 'Fire engine, fire truck (siren)',
    286: 'Air horn, truck horn',
    287: 'Reversing beeps',
    288: 'Train',
    289: 'Train whistle',
    290: 'Train horn',
    291: 'Railroad car, train wagon',
    292: 'Train wheels squealing',
    293: 'Subway, metro, underground',
    294: 'Aircraft',
    295: 'Aircraft engine',
    296: 'Jet engine',
    297: 'Propeller, airscrew',
    298: 'Helicopter',
    299: 'Fixed-wing aircraft, airplane',
    300: 'Bicycle',
    301: 'Skateboard',
    302: 'Engine starting',
    303: 'Idling',
    304: 'Accelerating',
    305: 'Revving',
    306: 'Car passing by',
    307: 'Race car, auto racing',
    308: 'Auto rickshaw',
    309: 'Go-kart',

    // Religious
    323: 'Bell',
    324: 'Church bell',
    325: 'Jingle bell',
    326: 'Bicycle bell',
    327: 'Chime',
    328: 'Wind chime',
    329: 'Gong',
    330: 'Tuning fork',

    // Other common environmental sounds
    331: 'Silence',
    332: 'Background noise',
    333: 'White noise',
    334: 'Pink noise',
    335: 'Static',
    336: 'Hiss',
    337: 'Pop',
    338: 'Crack',
    339: 'Crunch',
    340: 'Rustle',
    341: 'Whir',
    342: 'Clang',
    343: 'Thud',
    344: 'Thump',
    345: 'Creak',
    346: 'Scrape',
    347: 'Rub',

    // Sports and recreation
    374: 'Gym',
    375: 'Weight lifting',
    376: 'Exercise',
    377: 'Aerobics',
    378: 'Yoga',
    379: 'Stretching',
    380: 'Running',
    381: 'Jogging',
    382: 'Treadmill',
    383: 'Bowling',
    384: 'Billiards',
    385: 'Pool (game)',
    386: 'Swimming',
    387: 'Diving',
    481: 'Water polo',
    482: 'Playground',
    484: 'Stadium',
    485: 'Sports crowd',
    486: 'Audience',
    487: 'Cheering (sports)',
    488: 'Booing',
    489: 'Whistle (referee)',
    490: 'Air horn (sports)',
    491: 'Skateboard (trick)',
    492: 'Surfing',
    493: 'Snowboarding',
    494: 'Skiing',
    495: 'Ice skating',
    496: 'Rollerblading',
    497: 'Cycling (sport)',
    498: 'Mountain biking',
    499: 'Rock climbing',
    500: 'Martial arts',
    501: 'Boxing',
    502: 'Wrestling',
    503: 'Fencing',

    // Office and technology
    504: 'Printer',
    505: 'Copier',
    506: 'Scanner',
    507: 'Fax',
    508: 'Computer fan',
    509: 'Hard drive',
    510: 'Keyboard click',
    511: 'Mouse click',
    512: 'Office ambient',
    513: 'Cubicle',
    514: 'Meeting room',
    515: 'Conference call',
    516: 'Radio',
    517: 'Broadcast',
    518: 'Podcast',
    519: 'News broadcast',
    520: 'Talk show',
  };

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
    'Whistle (referee)': categorySports,
    'Mouth whistle': categoryBodySounds,
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

    // Sports and recreation (NEW)
    'Gym': categorySports,
    'Weight lifting': categorySports,
    'Exercise': categorySports,
    'Aerobics': categorySports,
    'Yoga': categorySports,
    'Stretching': categorySports,
    'Running': categorySports,
    'Jogging': categorySports,
    'Treadmill': categorySports,
    'Bowling': categorySports,
    'Billiards': categorySports,
    'Pool (game)': categorySports,
    'Swimming': categorySports,
    'Diving': categorySports,
    'Water polo': categorySports,
    'Playground': categorySports,
    'Stadium': categorySports,
    'Sports crowd': categorySports,
    'Audience': categorySports,
    'Cheering (sports)': categorySports,
    'Booing': categorySports,
    'Air horn (sports)': categorySports,
    'Skateboard (trick)': categorySports,
    'Surfing': categorySports,
    'Snowboarding': categorySports,
    'Skiing': categorySports,
    'Ice skating': categorySports,
    'Rollerblading': categorySports,
    'Cycling (sport)': categorySports,
    'Mountain biking': categorySports,
    'Rock climbing': categorySports,
    'Martial arts': categorySports,
    'Boxing': categorySports,
    'Wrestling': categorySports,
    'Fencing': categorySports,

    // Office and technology (NEW)
    'Printer': categoryOffice,
    'Copier': categoryOffice,
    'Scanner': categoryOffice,
    'Fax': categoryOffice,
    'Computer fan': categoryOffice,
    'Hard drive': categoryOffice,
    'Keyboard click': categoryOffice,
    'Mouse click': categoryOffice,
    'Office ambient': categoryOffice,
    'Cubicle': categoryOffice,
    'Meeting room': categoryOffice,
    'Conference call': categoryOffice,
    'Radio': categoryOffice,
    'Broadcast': categoryOffice,
    'Podcast': categoryOffice,
    'News broadcast': categoryOffice,
    'Talk show': categoryOffice,
    'Answering machine': categoryOffice,
    'Voicemail': categoryOffice,
    'Cash register': categoryOffice,
    'ATM': categoryOffice,
    'Point of sale': categoryOffice,
    'Barcode scanner': categoryOffice,
    'Calculator': categoryOffice,
    'Projector': categoryOffice,
    'Whiteboard': categoryOffice,
    'Shredder': categoryOffice,
    'Stapler': categoryOffice,

    // Other / Ambient
    'Silence': categoryOther,
    'Background noise': categoryOther,
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
        return typeAmbient;

      default:
        return typeAmbient;
    }
  }

  /// Get category from YAMNet class name or index
  static String getCategoryFromClassName(String className) {
    String? actualClassName;

    // Check if className is in format "YAMNet_Class_123"
    if (className.startsWith('YAMNet_Class_')) {
      final indexStr = className.replaceFirst('YAMNet_Class_', '');
      final classIndex = int.tryParse(indexStr);

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
    return _categorizeByKeywords(actualClassName, null);
  }

  /// Intelligent categorization for unmapped classes based on keywords
  static String _categorizeByKeywords(String className, int? classIndex) {
    final lower = className.toLowerCase();

    // Range-based fallback for gap indices where the class name is still
    // "YAMNet_Class_N" (no indexToClassName entry). Uses AudioSet ontology
    // structure to assign a reasonable category without guessing exact names.
    if (classIndex != null && className.startsWith('YAMNet_Class_')) {
      if (classIndex >= 137 && classIndex <= 228) return categoryMusic;
      if (classIndex >= 0 && classIndex <= 15) return categorySpeech;
      if (classIndex >= 16 && classIndex <= 35) return categoryBodySounds;
      if (classIndex >= 36 && classIndex <= 136) return categoryNature;   // 36-108 animals, 109-136 more animals
      if (classIndex >= 229 && classIndex <= 309) return categoryDomestic;
      if (classIndex >= 310 && classIndex <= 373) return categoryTraffic;  // 323-347 have named entries; raw gaps default to Traffic
      if (classIndex >= 374 && classIndex <= 387) return categorySports;
      if (classIndex >= 388 && classIndex <= 393) return categoryConstruction;
      if (classIndex >= 394 && classIndex <= 399) return categoryIndustrial;
      // Indices 137-228 (Music), 400-520: fall through to keyword checks below
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
      case categoryOther:
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}
