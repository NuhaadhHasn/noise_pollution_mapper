# Noise Mapper

**Community noise-pollution mapping with on-device AI sound classification.**

A Flutter app for measuring urban noise with a phone, recognising what is making
it, and sharing the readings on a community map. Built as a final-year academic
project (CIS6035) by Nuhaadh Hassan, with Sri Lankan cities in mind.

## Features

- **Noise measurement.** Live sound level in dB from the phone's microphone,
  saved with GPS coordinates and a place name.
- **On-device sound classification.** The YAMNet TensorFlow Lite model labels
  each 5-second window. Readings are grouped into 17 pollution categories
  (Traffic, Tuk-tuk, Construction, Industrial, Speech, Music, Religious, Market,
  Nature, Domestic, Alarm and others) plus Quiet. Low-confidence or ambiguous
  windows are reported as Uncertain and are never stored with a category. A
  built-in guide explains the categories.
- **Community map.** Colour-coded markers with clustering, a heatmap, and
  community feed and search views of what others have recorded.
- **Analytics.** Charts and statistics by time, noise band and sound category.
- **History and export.** Your recordings, with delete and Undo, and CSV export.
- **Offline first.** Readings recorded without a connection are queued and
  synced later.
- **Alerts and themes.** An optional high-noise alert with a configurable
  threshold, and light and dark themes with eight accent colours.
- **Optional donations.** Display settings come from Firestore, never from the
  app bundle.

## Measurement accuracy

**Decibel readings are uncalibrated estimates, not metrological measurements.**

Levels come from the phone's own microphone via a single hardcoded calibration
offset (-10 dB), hand-tuned so that everyday scenes land in plausible ranges
(quiet room 30-40 dB, normal conversation 60-70 dB, traffic 70-85 dB). There is
no calibration against a reference sound-level meter and no per-device profile,
so the same sound will read differently on a different handset. Phone hardware
also cannot apply professional A/C frequency weighting or fast/slow response
modes, which is why the app does not offer those controls.

Treat the numbers as **indicative, and comparable only within one device**: use
them for relative trends and hotspot detection, not as evidence of an absolute
sound level. The dashboard states this next to the live reading.

Sound categories are best-effort for the same reason. Predictions below 30%
confidence, and near-ties between two different categories where which one wins
is arbitrary, are reported as `Uncertain`. Enable **Settings > Diagnostics >
Show Top-3 Predictions** to see what the model ranked for each window.

## Privacy

- Readings are shared with other signed-in users on the community map. Each
  reading carries the exact GPS position and time, so only record where you are
  comfortable being located.
- Your email address is never written to the shared readings. They carry a
  masked author label (or your display name) instead, and your profile document
  is readable only by you.
- Deleting your account anonymises your readings and deletes the sign-in.
- Firestore security rules validate every write (field types, ranges and keys) and
  only let you change your own data. They live in `firestore.rules` and are
  tested against the Firestore emulator.
- The app bundles no secrets. Firebase client config is public by design;
  see `docs/SECURITY_ROTATION.md` for the key-restriction runbook.

## Tech stack

- Flutter and Dart (SDK `^3.10.3`)
- TensorFlow Lite with the YAMNet model (`tflite_flutter`)
- Firebase Auth and Cloud Firestore
- `noise_meter` and `flutter_sound` for audio, `geolocator` and `geocoding` for
  location
- `flutter_map` with OpenStreetMap tiles and marker clustering, `fl_chart` for
  charts
- `provider` and `ValueNotifier` for state; `hive` and `shared_preferences` for
  local storage

## Setup

Prerequisites: the Flutter SDK, Android Studio or VS Code, and an Android
device or emulator. Android is the tested platform; iOS is configured but not
extensively tested; there is no web build because the app needs the microphone.

```bash
git clone https://github.com/NuhaadhHasn/noise_pollution_mapper.git
cd noise_pollution_mapper
flutter pub get
flutter run
```

No `.env` file is used. Firebase client config is generated in
`lib/firebase_options.dart` and `android/app/google-services.json` with
`flutterfire configure`; to run against your own project, register your own
Firebase app and regenerate them. Donation display config is read from the
Firestore document `app_config/donations` (`paypalBusinessEmail`,
`paypalSandboxMode`, `buyMeACoffeeUrl`).

Build a release APK with `flutter build apk --release`. It must be signed with
your own release keystore; see `docs/SECURITY_ROTATION.md` for the release
verification steps.

## Testing

```bash
flutter analyze
flutter test                # unit and widget tests, including a flow test
flutter test test/unit/     # unit tests only
flutter test test/widget/   # widget tests only
```

Tests cover classification gating, CSV export, offline queueing, privacy of
writes, analytics bucketing, Undo and snackbar behaviour, and the main screens.
The model itself needs real audio, so classification quality is checked on a
device; see `audit/12_CLASSIFICATION_FIELD_TEST.md`.

## Firebase rules and indexes

The security rules in `firestore.rules` and the one composite index in
`firestore.indexes.json` (`noise_readings`: `userId` ascending, `timestamp`
descending) are the source of truth for the whole project, including the web
dashboard. The project has no Storage bucket. Deploy only with an explicit
target list, after reviewing the diff:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Never run a bare `firebase deploy` or `--only storage`.

## Project structure

```
lib/
  main.dart                  App entry point
  firebase_options.dart      Generated Firebase config
  models/                    Data models
  screens/                   Dashboard (recording), map, analytics, history,
                             community feed, search, settings, profile, auth,
                             onboarding, classification guide, donation
  services/                  Firestore, offline sync, classification (YAMNet),
                             notifications, heatmap, profile sync
  utils/                     CSV builder, stats, logger, snackbars, theme helper
  widgets/                   Reusable UI (gauge, nav bar, stop bar, charts)
  theme/                     App theme
assets/models/               YAMNet model and class map
test/                        Unit, widget and flow tests
docs/                        Security and key rotation runbook
audit/                       Audit reports and the fix playbook
```

## Status

Feature complete and audited. The full end-to-end audit (see `audit/`) was
fixed and shipped, and the app has been checked on a physical Android phone.
Classification accuracy with clean field samples is still being evaluated.

## License

An academic project developed for educational purposes. No open-source licence
is granted.

## Acknowledgements

YAMNet by Google Research, Firebase and Flutter by Google, and OpenStreetMap for
map tiles.
