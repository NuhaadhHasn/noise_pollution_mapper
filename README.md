# 🔊 Noise Mapper

**Urban Noise Pollution Monitoring System with AI Sound Classification**

A Flutter-based mobile application designed for the Sri Lankan government to monitor and analyze urban noise pollution through community-driven data collection.

---

## 📱 About the Project

**Developer:** Nuhaadh Hassan (20230670, KD/BSCSD/20/74)
**Institution:** Final Year Academic Project (CIS6035)
**Timeline:** 3 months development (2025-2026)
**Status:** ✅ Complete - All 14 bugs fixed, ready for testing & documentation

### Key Features

- **Real-time Noise Measurement**: Capture and analyze environmental sound levels (dB)
- **AI Sound Classification**: Powered by YAMNet TensorFlow Lite model
  - 10 sound categories: Traffic, Tuk-tuk, Music, Speech, Construction, Nature, Animals, Sirens, Machinery, Other
  - Pollution vs Ambient classification
  - Real-time confidence scores
- **GPS Location Tracking**: Automatic geocoding of noise measurements
- **Community Map**: Interactive map with color-coded noise level markers
- **Analytics Dashboard**: Charts, statistics, and sound type breakdowns
- **History & Export**: CSV export with classification data
- **Firebase Integration**: Authentication, cloud storage, and real-time sync
- **Dark Mode & Themes**: 8 customizable theme colors with dark/light mode support
- **Local Notifications**: High noise level alerts at 70dB threshold

---

## 🎯 Project Purpose

This app enables government agencies and citizens to:
- Monitor urban noise pollution in real-time
- Identify noise pollution hotspots
- Classify sound sources (traffic, construction, etc.)
- Generate community-driven noise maps
- Export data for environmental analysis

---

## 🏗️ Tech Stack

- **Framework**: Flutter 3.x (Dart)
- **AI/ML**: TensorFlow Lite (YAMNet model)
- **Backend**: Firebase (Auth, Firestore, Cloud Storage)
- **State Management**: Provider & ValueNotifier
- **Audio Processing**: flutter_sound, noise_meter packages
- **Maps**: flutter_map (OpenStreetMap)
- **Local Storage**: shared_preferences
- **Testing**: 120+ test cases (unit, widget, integration)

---

## 📦 Installation

### Prerequisites

- Flutter SDK 3.x or higher
- Android Studio / VS Code
- Android device/emulator (Android 7.0+)
- Firebase project setup

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd noise_pollution_mapper
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configuration** — no `.env` file is used. Firebase client config is
   generated in `lib/firebase_options.dart` (via `flutterfire configure`).
   Donation display config is served from the Firestore document
   `app_config/donations` (fields: `paypalBusinessEmail`, `paypalSandboxMode`,
   `buyMeACoffeeUrl`). Secrets are never bundled with the app
   (see `docs/SECURITY_ROTATION.md`).

4. **Run the app**
   ```bash
   flutter run
   ```

5. **Build APK** (for distribution)
   ```bash
   flutter build apk --release
   ```

---

## 🧪 Testing

### Run Automated Tests
```bash
# All tests
flutter test

# Unit tests only
flutter test test/unit/

# Widget tests only
flutter test test/widget/

# Integration tests (requires device)
flutter test integration_test/
```

### Manual Testing
See `TESTING_GUIDE.md` for comprehensive testing checklist covering:
- All 12 screens
- AI sound classification
- Map and analytics features
- Settings and account management
- Bug fix verification tests

---

## 📂 Project Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── screens/                     # All 12 app screens
│   ├── splash_screen.dart
│   ├── onboarding_screen.dart
│   ├── login_screen.dart
│   ├── registration_screen.dart
│   ├── dashboard_screen.dart    # Main recording screen
│   ├── map_view_screen.dart     # Interactive map
│   ├── analytics_screen.dart    # Charts & statistics
│   ├── history_screen.dart      # Recording history + CSV export
│   ├── settings_screen_enhanced.dart
│   ├── report_noise_screen.dart
│   ├── search_list_screen.dart
│   └── community_feed_screen.dart
├── services/
│   ├── firebase_service.dart    # Firestore operations
│   ├── notification_service.dart
│   ├── sound_classification_service.dart  # ML inference
│   └── yamnet_class_mapping.dart          # Sound categories
├── widgets/                     # Reusable UI components
├── utils/
│   ├── app_logger.dart          # Logging utility
│   └── animations.dart          # Custom animations
└── theme/
    └── app_theme.dart           # Theme system
```

---

## 🔑 Key Files

- **`CLAUDE.md`**: Development context and session history
- **`BUG_FIXES_SESSION_15.md`**: Complete bug tracking (all 14 bugs fixed)
- **`TESTING_GUIDE.md`**: Comprehensive testing instructions
- **`PRODUCTION_CHECKLIST.md`**: Production readiness checklist
- **`HOW_TO_FIND_FIREBASE_VALUES.md`**: Firebase configuration guide

---

## 🎓 Academic Project Details

### Features Implemented

**Phase 1: Core Features** (Sessions 1-6)
- All 12 screens
- Firebase Authentication
- Real-time noise measurement
- GPS location tracking
- Map with markers

**Phase 2: AI Integration** (Sessions 7-10)
- YAMNet model integration
- Real-time sound classification
- Audio capture and processing
- Classification persistence

**Phase 3: Polish & Testing** (Sessions 11-14)
- Code quality improvements (0 errors)
- Logger system implementation
- Environment variables setup
- 120+ automated tests
- Security hardening

**Phase 4: Bug Fixing** (Sessions 15-19)
- User testing conducted
- 14 bugs identified and fixed
- All critical, high, and medium priority issues resolved
- Production-ready state

---

## ✅ Current Status

**Development**: ✅ 100% Complete
**Bug Fixes**: ✅ 14/14 Fixed (100%)
**Code Quality**: ✅ 0 Errors, 0 Warnings
**Testing**: ✅ 120+ Test Cases Created
**Documentation**: 🔄 In Progress

---

## 📝 Test User Account

**Email**: test@example.com
**Password**: test123

---

## 🔒 Firebase Security

Production security rules are active:
- Authentication required for all operations
- Users can only modify their own data
- Read access granted for community features
- Data validation enforced

---

## 📱 Supported Platforms

- ✅ Android 7.0+ (API Level 24+)
- ✅ iOS (configured, not extensively tested)
- ❌ Web (not supported - requires microphone access)

---

## 🐛 Known Issues

None - All 14 identified bugs have been fixed in Sessions 15-19.

---

## 📄 License

This is an academic project developed for educational purposes.

---

## 👨‍💻 Developer

**Nuhaadh Hassan**
Student ID: 20230670 (KD/BSCSD/20/74)
Final Year Project - CIS6035
Contact: [Your Email/Contact]

---

## 🙏 Acknowledgments

- YAMNet model by Google Research
- Firebase by Google
- Flutter framework by Google
- OpenStreetMap for map tiles
- Sri Lankan government for project sponsorship

---

**Project Status**: Ready for final testing and documentation phase
**Last Updated**: 2026-01-29 (Session 19)
