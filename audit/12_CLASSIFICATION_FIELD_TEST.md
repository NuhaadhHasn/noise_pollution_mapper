# 12 — Classification Field Test (on-device) and Open Issues

Field test of the YAMNet classification pipeline on real hardware, after the
59-commit fix playbook shipped. This document records what was tested, what the
results actually mean, and the open issues to fix **before** starting the web
dashboard audit.

- **Device:** Samsung Galaxy SCV39 (Galaxy S9+), Android 10 / API 29
- **Date:** 2026-09-10
- **Build:** debug APK off `master` @ `59eb1d6`, threshold 0.30, official
  `assets/models/yamnet_class_map.csv` (521 classes)
- **Method:** sounds played through the phone speaker and via the owner holding
  the source next to the microphone; classification read from the Analytics
  "Sound Categories" panel and from `AppLogger` output.

---

## 1. Results

| Sound | Reported category | Verdict |
|---|---|---|
| Speech (owner speaking) | Speech | ✅ correct |
| Finger snap | Body Sounds (99.2%) | ✅ correct |
| Piano (`qa_piano.ogg`) | Music (96.9%) | ✅ correct |
| Church bell | Religious | ✅ correct |
| Bird/wildlife (owner's own sample) | Nature | ✅ correct |
| Car horn (`qa_carhorn_loop.wav`) | Traffic | ✅ correct |
| Real ambient street noise | Traffic (33–80%) | ✅ correct |
| Bird (`qa_birds.mp3`, xeno-canto) | mostly Traffic, briefly Nature | ⚠️ see §2.1 |
| Motorcycle (`qa_motorcycle_loop.wav`) | Traffic, sometimes Music | ⚠️ see §2.2 |
| Train (`qa_train_loop.wav`) | Music | ⚠️ see §2.3 — bad sample |
| Small AC unit | 45 dB, Traffic | ⚠️ see §2.2 and §3 |

**7 of 11 correct. 8 of the app's 18 categories are now confirmed working**
(Speech, Body Sounds, Music, Religious, Nature, Traffic, plus the below-threshold
`Uncertain` path and null-persistence). Categories still unconfirmed: Tuk-tuk,
Construction, Industrial, Market, Domestic, Alarm, Transport, Sports, Weather,
Office, Other, Quiet.

> **Update (2026-09-11).** `Quiet` is new — added in `86c8c35` so a genuinely
> silent room reads as `Quiet` rather than the uninformative `Other`. Only the
> YAMNet class `Silence` maps to it; the room-tone classes (`Inside, small
> room`, etc.), `White noise`, `Static` and `Environmental noise` deliberately
> stay in `Other`, because "enclosed space" is not "quiet" and a 55 dB room
> labelled Quiet would be worse than the status quo.

---

## 2. Diagnosis — the mapping is NOT at fault

Grepping `lib/services/yamnet_class_mapping.dart` shows the taxonomy is correct
for every anomaly reported:

```
'Motorcycle'       -> categoryTuktuk      (NOT Traffic)
'Air conditioning' -> categoryIndustrial  (NOT Traffic)
'Church bell'      -> categoryReligious   (matches observed)
```

So when a motorcycle or an AC reported **Traffic**, YAMNet was **not detecting
those classes at all**. It detected a traffic class — i.e. the ambient street
noise — and the intended sound never became the top prediction.

### 2.1 Root cause: the app uses only the top-1 prediction

`lib/services/sound_classification_service.dart:121`, as it stood at
`59eb1d6` (the ranking is computed once since `b62db64`):

```dart
final maxIndex = _getMaxIndex(scores);
final confidence = scores[maxIndex];
```

A single `argmax` over the raw output vector, with no margin check.

> **Correction (2026-09-11).** An earlier draft of this section called that
> output "one 521-way softmax". That is wrong. `output[0]` is read raw —
> there is no softmax, no `exp`, and no normalisation anywhere in `lib/`.
> YAMNet is an AudioSet **multi-label** classifier: it emits **521
> independent per-class scores**, each its own logistic output, so they do
> not sum to 1 and several can legitimately be high at once. This is not a
> pedantic point — the fix in §4.1 rests on it. Because the scores are not
> shares of one probability mass, the ambiguity gate has to compare two
> **absolute** confidences; a relative or ratio margin would have no
> meaning here.

Consequences:

- In any environment with steady background noise, the top class tends to be
  that background, not the sound of interest.
- A control run with **zero audio playing** still classified `Traffic` at
  33–58%. That is the baseline this location produces, and it is *correct* — but
  it means any test result equal to the ambient profile proves nothing.
- The intended class is often present at #2 or #3. The service **already logs
  this** at `sound_classification_service.dart:131`:
  `🎵 YAMNet Top 3: #idx=Name (x%), #idx (y%), #idx (z%)`.
  Reading that line is the fastest way to confirm this hypothesis per sound.

### 2.2 Why "Traffic" for motorcycle and AC

Both are broadband low-frequency drones, acoustically close to distant road
noise, and both were played *into* an environment already dominated by road
noise. The recording microphone hears the sum. Expected under §2.1.

### 2.3 Sample-quality caveats — several "failures" are the test's fault

Three of the four anomalies trace to the samples chosen by the assistant, not
to the app:

- **`qa_train_loop.wav`** is *File:Taiwan Railway Destination Sound* — a station
  announcement **jingle**. It is literally music. The owner independently
  observed this ("train sound actually it does sound like a music"). Classifying
  it as Music is **correct behaviour on a mislabelled sample.** Discard this
  result; re-test with a genuine passing-train recording.
- **`qa_birds.mp3`** is a xeno-canto field recording (Black-capped Sparrow) with
  substantial background hiss and wind. The owner's own bird/wildlife sample
  classified as **Nature** correctly — which isolates the fault to the sample.
- **`qa_motorcycle_loop.wav`** was built by looping a 14.5 s clip five times.
  Looping introduces strong periodicity, which plausibly pushes YAMNet toward a
  rhythmic/musical class — a likely contributor to the intermittent "Music".
  Any future looped sample should cross-fade or use a naturally long recording.

---

## 3. Is 45 dB correct for a small AC on an S9+?

**Plausible, but the app's absolute accuracy is unverified.**

`lib/screens/dashboard_screen.dart:509`

```dart
const double calibrationOffset = 10.0;
final rawDb = reading.meanDecibel - calibrationOffset;
```

A single hardcoded −10 dB offset, hand-tuned against the targets written in the
adjacent comment: quiet room 30–40, conversation 60–70, loud speech 80–90,
traffic 70–85. A small AC at 45 dB sits sensibly between "quiet room" and
"conversation", so the reading is **internally consistent**.

What it is *not*: a calibrated sound-level measurement. There is no reference
against an SPL meter, no per-device profile, and no frequency weighting (the
playbook removed the dBA/dBC controls precisely because phone hardware cannot
do it — finding settings-6/uiux-1). The same AC on a different handset will read
differently. Treat all absolute dB values as **indicative, not metrological**,
and say so anywhere the number is presented as fact.

---

## 4. Open issues to fix before the dashboard audit

Ranked by value. **Status as of 2026-09-11:** items 1, 3 and 5 are closed
(commit SHAs inline); item 4 is decided; items 2 and 6 are still open.

1. ✅ **CLOSED — `b62db64`.** *Add a top-1 margin gate (HIGH).* When
   `scores[top] - scores[second]` is small, the prediction is a coin-flip
   between the ambient profile and the real source. Implemented as
   `SoundClassificationService.ambiguityMargin` (0.10, an absolute gap — see
   the correction in §2.1): a near-tie whose two classes fall in **different**
   app categories is reported as the live-only `Uncertain` pseudo-category and,
   exactly like a sub-threshold result, is never persisted with a class.
   Near-ties inside one category are exempt. See item 4 for the one behaviour
   change this causes in the field.
2. **Re-test with clean samples (HIGH).** Replace the train and bird samples;
   rebuild the motorcycle sample without naive looping. Then re-run the 11-sound
   matrix. Until then, 3 of the 4 "failures" are unproven.
   *Update 2026-10-16:* done with 18 clean, licensed samples. See §7, which
   also adds the specific-over-broad rule that the results called for.
3. ✅ **CLOSED — `7512c1f`.** *Surface the Top-3 in a debug view (MEDIUM).*
   The ranked candidates now travel on `ClassificationResult.topPredictions`
   and render on the dashboard behind the `show_classification_debug`
   preference (default off). Display-only — nothing extra is persisted. A
   field test no longer needs `adb logcat` to see what the model ranked.
4. ✅ **DECIDED — keep it.** *Confirm `Motorcycle` → `Tuk-tuk` is intended
   (MEDIUM).* A motorcycle is not a three-wheeler, but the mapping is a
   deliberate Sri Lanka localisation. The owner chose to keep `Tuk-tuk` with
   all five of its classes (`Motorcycle`, `Scooter`, `Small engine`,
   `Auto rickshaw`, `Go-kart`); readings in Firestore already use it.

   **Known side effect of the §4.1 gate — do not file this as a new bug.**
   `Vehicle` maps to Traffic and `Motorcycle` maps to Tuk-tuk: a parent and
   its child in *different* app categories. At the roadside those two
   routinely score within the 10pp margin of each other, so a tuk-tuk or a
   motorcycle recorded near traffic will now often report **`Uncertain`
   instead of `Tuk-tuk`**. That is the gate working as designed — which of
   the two wins in that environment is a coin flip — but it does make
   `Tuk-tuk` harder to confirm in the field. Test it away from a road.

   *Superseded 2026-10-16 (§7):* `Vehicle` is now a broad catch-all, so a
   `Motorcycle` within 0.15 of it reports `Tuk-tuk` instead of `Uncertain`.
5. ✅ **CLOSED — `76947c2`.** *Document the dB accuracy limitation (MEDIUM).*
   The "uncalibrated estimate" caveat is now disclosed in the app, per §3.
6. **Calibrate against a reference SPL meter (LOW / optional).** The only way to
   make the numbers defensible. A phone-based reference is not sufficient.

---

## 5. Test-method notes (read before repeating this)

- **`adb logcat -c` does not clear the buffer on this device.** Stale lines will
  be read back as fresh results — this produced one entirely false "piano →
  Traffic" conclusion mid-session. Use a device-clock marker instead:
  `adb logcat -d -T "$(adb shell 'date +"%m-%d %H:%M:%S.000"')"`.
- **Use a dwell press, not a tap.** `adb shell input tap X Y` is frequently
  ignored by Flutter's gesture recogniser here; `adb shell input swipe X Y X Y 120`
  is reliable. Many apparent "dead button" failures were this.
- **Playing audio from another app backgrounds the app under test**, which stops
  recording by design (dash-6, cluster 05 Step 3). Start playback first, return
  to the app, *then* record — and use a clip longer than ~30 s.
- **Confirm which screen is showing before tapping.** Repeated blind taps at the
  nav/record coordinates while Settings was open **dragged the sliders**,
  silently changing `save_frequency` 30→5 and `recording_duration_minutes` 1→11
  and manufacturing a fake "pref not honoured" bug.
- **Clean up afterwards.** This session wrote 61 test readings to production
  Firestore; all 61 were deleted on 2026-09-10. Verify with a date-filtered
  query, not by eye.
- **USB on this machine:** native Windows `adb` hangs with no output and is
  unusable. Use WSL + usbipd: `usbipd bind --force --busid 3-1` (admin, once),
  keep a WSL shell alive, then `usbipd attach --wsl --busid 3-1`. Attach fails
  while any Windows `adb.exe` holds the device — kill it first. The link drops
  every few minutes; run each device task as its own short job.

---

## 6. What is NOT affected

The classification anomalies above are **selection/environment issues, not
regressions in the shipped playbook**. Verified separately on-device and still
holding:

- Official 521-class CSV loads; init fails fast without it (ml-1)
- Confidence threshold reads 0.30; below-threshold results are never persisted
  with a class — two readings stored `soundClass=null, confidence=null` (ml-3/ml-4)
- Category taxonomy is exact-match via `soundTypeForStoredClass` (flow3-8)
- `authorLabel` masking on write; the 3,328-doc backfill holds at 0 raw emails (sec-2)
- The §4.4 `main_app_shell.dart` merge (both cluster 03 and 05 lines fire)
- The §4.5 guarded-bootstrap reminder re-sync

---

## 7. 2026-10-16 clean-sample re-test

Closes §4 item 2. This section was added afterwards; §1–§6 above are left as
written on 2026-09-10/11.

- **Device:** same Galaxy S9+ (SCV39), Android 10 / API 29.
- **Build:** the debug APK installed for the 2026-10-16 device QA. It had the
  0.30 threshold and the 0.10 near-tie gate, but not the rule below.
- **Samples:** 17 clean, licensed recordings from Wikimedia Commons (CC0,
  CC BY, CC BY-SA or public domain; sources are in the QA scratchpad
  `sources_set1.json` / `sources_set2.json`), plus a generated 30 s silent
  file. None is looped. The train and bird samples replace the bad ones
  from §2.3.
- **Method:** each clip was played through the phone's own speaker from the
  Samsung Sound Player pop-up while the app recorded. The Top-3 came from the
  `🎵 YAMNet Top 3` log line, one row per 5 s window. The last window of most
  runs comes after playback ended, so it measures the room (often `Speech`, the
  operator) and is ignored below. A control run had nothing playing.

### 7.1 Results

"Before" is what this build reported per 5 s window. "With §7.2" is the same
score vectors replayed through the new rule (every logged window was
replayed; see §7.3).

| Sample | Before (per window) | With §7.2 | What YAMNet scored |
|---|---|---|---|
| Train passing (Wirikuta) | Traffic ×3, **Uncertain ×10**, Traffic | Traffic ×3, **Transport ×10**, Traffic | Vehicle 0.89–0.996 vs Rail transport 0.80–0.98, Train next. One window had Rail transport 0.957 over Vehicle 0.941. The first three windows (the approach; Siren/Emergency vehicle in two) stay Traffic |
| Jawa 350 motorbike | **Uncertain**, Traffic, **Uncertain**, Traffic | **Tuk-tuk**, Traffic, **Tuk-tuk**, Traffic | Vehicle 0.738 / Motorcycle 0.668, then Motorcycle 0.414 / Vehicle 0.332. Two windows have Vehicle 0.586 with Motorcycle 0.172 or more below, outside the margin |
| Helicopter (Chinook) | Traffic, Traffic, **Uncertain** | Traffic, Traffic, **Transport** | Vehicle 0.50 / Helicopter 0.414 / Aircraft 0.332. Earlier windows: Vehicle with Motorboat or Motorcycle 0.168 or more below |
| Thunder crack | Uncertain (low), **Uncertain**, Uncertain (low) | Uncertain (low), **Weather**, Uncertain (low) | Thunderstorm = Water = Rain = 0.414 |
| Rain + thunder | Nature ×3 | Nature ×3 | Water/Waterfall 0.33–0.74, Waves, Ocean. Rain at most 0.332, 0.41 below Water: the rule cannot help |
| Motorcycles at Praterstern (14.5 s clip) | Speech, Traffic, Uncertain (low) ×2 | unchanged | Vehicle 0.50 / Motor vehicle (road) / Truck. No Motorcycle in the top-3. Later windows (Music) were after the clip ended |
| Airplane | Traffic ×3 | Traffic ×3 | Vehicle 0.41–0.50, Rail transport/Train at most 0.26. No aircraft class in the top-3 |
| Crowd | Traffic, Uncertain (low), Speech ×2 | unchanged | First window Vehicle 0.668 / Subway 0.50 (gap 0.168, outside the margin) |
| Blackbird | Uncertain ×2, Nature, Uncertain, Nature | unchanged | Animal/Bird 0.891; Frog 0.50 |
| Hammer drill | Construction ×2, Uncertain, Construction | unchanged | Tools/Jackhammer. The Uncertain window is Engine 0.414 = Jackhammer 0.414. Engine is not broad |
| Chainsaw | Industrial ×3 | unchanged | Light engine / Chainsaw 0.80–0.96 |
| Milling machine | Traffic, Uncertain (low) ×2 | unchanged | Vehicle 0.20–0.33 |
| Blender | Construction, Traffic, Uncertain, Construction | unchanged | Tools 0.852; one window Vacuum cleaner 0.50 vs Tools 0.414 |
| Printer | Uncertain (low), Uncertain, Office | unchanged | Printer 0.50 vs Mechanisms 0.414, then Printer 0.738 |
| Alarm clock (electronic) | Music ×2 | unchanged | Synthesizer 0.50–0.668 |
| Alarm clock (mechanical) | Construction, Uncertain (low) | unchanged | Tools 0.332, then Alarm/Buzzer 0.148 |
| Sewing machine | Uncertain (low) ×4 | unchanged | Nothing reached 0.30 |
| Silence (30 s silent file), two runs | Uncertain, Traffic, Speech ×2 / Speech, **Uncertain**, Traffic ×2 | unchanged / Speech, **Speech**, Traffic ×2 | The room, not the file. The changed window is Speech 0.332 = Vehicle 0.332. `Silence` never ranked, so `Quiet` never appeared |
| Control, nothing playing | Traffic ×2, Uncertain (low) ×2 | unchanged | **Vehicle 0.738 (Rail transport 0.332) and 0.801**: this room's baseline |

Read with the control row in mind. In this room, `Vehicle` sits at 0.74–0.80
with nothing playing, so a sample is only informative if it beats that baseline
or the rule replaces it.

### 7.2 The rule: prefer the specific class over a broad catch-all

YAMNet's broad class `Vehicle` (mapped to Traffic) fires alongside every
train, aircraft and motorcycle, and `Water` (Nature) alongside rain. With the
top-1 plus the 0.10 near-tie gate, **Transport and Tuk-tuk were effectively
unreachable**: the train was Uncertain in all ten of its windows.

Owner-approved fix, implemented in
`SoundClassificationService.decideCategory`:

> When the **top** class is a broad catch-all and a **specific** class that maps
> to a **different** app category is in the top-3, with a score ≥ 0.30 **and**
> within an absolute **0.15** of the broad class, report the specific class:
> its category and its own score.

- **Broad set:** `{Vehicle, Water}`, exactly. The justification, including
  why `Motor vehicle (road)` and `Engine` are left out, is in the doc comment
  on `SoundClassificationService.broadCatchAllClasses`.
- **Absolute margin**, like the 0.10 gate, because the 521 scores are
  independent sigmoids (§2.1 correction).
- **The strongest specific class decides.** The candidate is the
  highest-ranked non-broad class in the top-3. If it shares the broad
  class's category (Vehicle over Car), Traffic is already right and nothing
  changes.
- **Mirror case.** A broad runner-up never gates a specific winner. The
  train had one window with Rail transport 0.957 over Vehicle 0.941. The
  rule would let Rail transport win from 0.15 *below* Vehicle, so it must
  also win from above. The same applies to the thunderstorm tie, whichever
  of the tied classes sorts first.
- **Unchanged:** the 0.30 threshold on the top-1; the 0.10 gate between two
  specific classes in different categories (a promoted class is still gated
  by a competing specific class); the same-category exemption; `Quiet` maps
  only `Silence`; below-threshold and near-tie results are still saved
  without a class (`utils/classify_then_save.dart`). A promoted result is
  saved with the specific class, its category and its own score.
- **Logged** at debug level when it fires, for example:
  `Specific over broad: Rail transport (98.4%) over Vehicle (99.6%) -> Transport`.
  The dashboard's near-tie reason now names the pair the gate actually
  compared.

### 7.3 Replay and what is still open

All 154 Top-3 lines logged on 2026-10-16 (the 18 samples above plus a
4.5-minute room recording and two short runs) were replayed through the old and
the new decision. **15 windows changed, and every one went from `Uncertain` to
a category:** train ×10 → Transport, Jawa ×2 → Tuk-tuk, helicopter → Transport,
thunder → Weather, silence run 2 → Speech. **No window that already had a
category changed.** That includes all 54 windows of the room recording (34
Traffic, 7 Speech, 3 Music, 10 Uncertain).

Still open:

- **Re-test on device** with this build. These are replayed logs, not live
  runs; the log line above makes each decision self-explanatory.
- **Airplane, Praterstern and rain did not move.** YAMNet never put an
  aircraft class, a motorcycle class or `Rain` close enough to the top, so no
  ranking rule can rescue them. Re-test at a lower ambient level, or with the
  phone away from the speaker's low-frequency boom.
- **Watch `Motor vehicle (road)`.** If a re-test shows it at #1, or within
  0.10 of a `Motorcycle`, it is the next broad-set candidate.
