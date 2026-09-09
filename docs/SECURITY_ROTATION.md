# Key Rotation & Verification Runbook (audit finding critic-02)

Prior releases bundled `.env` inside the APK (`assets/flutter_assets/.env`),
exposing every value in it to anyone who unzipped the APK. The bundling
mechanism was removed; the values below must be treated as public and
rotated/restricted. Perform each item once and check it off in the PR.

## 1. PayPal
- The shipped `PAYPAL_CLIENT_ID` was a PayPal *business email* (public by
  design in `cmd=_donations` URLs) — no rotation possible or needed.
- `PAYPAL_SECRET` was never present in the shipped `.env`, but `.env.example`
  instructed developers to place a real REST secret there. If any PayPal REST
  app credentials were EVER created for this project (the old `.env` carried a
  "PROD WORKING!" comment), log in to developer.paypal.com -> My Apps &
  Credentials and regenerate/delete that app's secret now.
- Policy going forward: the client only ever holds the business email, served
  from Firestore `app_config/donations`. Any future PayPal REST integration
  (orders/capture/refunds) MUST go through a server (e.g. Cloud Function)
  holding the secret.

## 2. Firebase API key (`FIREBASE_API_KEY`, also in firebase_options.dart)
Firebase client API keys are not secrets, but the exposed key should be
restricted: Google Cloud Console -> APIs & Services -> Credentials ->
the Android/iOS keys ->
- Application restrictions: Android apps (package
  `com.noisemapper.noise_pollution_mapper` + the SHA-1 of the NEW release
  keystore from playbook Step 2) / iOS bundle ID.
- If abuse is suspected, regenerate the key and re-run `flutterfire configure`
  to refresh `lib/firebase_options.dart` and `google-services.json`.

## 3. Google Maps API key
The shipped value was the placeholder `your_google_maps_key_here` — nothing to
rotate. If a real Maps key exists in any console project, restrict it the same
way before use.

## 4. Personal data
The old `.env` contained a personal Gmail address in a comment; the file is
deleted and gitignored. Do not reintroduce personal data in config files.

## 5. Release verification (every release)
```bash
flutter build apk --release
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i "\.env"   # must print nothing
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk  # must NOT be CN=Android Debug
```
