import 'package:flutter/material.dart';
import 'dart:async';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../utils/animations.dart';
import '../utils/app_logger.dart';
import '../utils/theme_helper.dart';
import '../utils/shared_app_state.dart';
import '../utils/noise_stats.dart';
import '../utils/classify_then_save.dart';
import '../utils/microphone_unavailable_snack_bar.dart';
import '../utils/no_audio_watchdog.dart';
import '../widgets/decibel_meter_gauge.dart';
import '../widgets/noise_history_chart.dart';
import '../widgets/recording_stop_bar.dart';
import '../widgets/sync_status_indicator.dart';
import 'settings_screen_enhanced.dart';
import 'splash_screen.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/sound_classification_service.dart';
import '../services/sync_service.dart';
import 'community_feed_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  final bool isInAppShell;

  const DashboardScreen({super.key, this.isInAppShell = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  final SoundClassificationService _classificationService =
      SoundClassificationService();

  // Noise measurement
  bool _isRecording = false;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  NoiseMeter? _noiseMeter;

  // Audio capture for classification
  FlutterSoundRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamController<Uint8List>? _audioStreamController;
  final List<double> _audioBuffer = [];
  static const int _targetSampleRate = 16000; // YAMNet requires 16kHz
  static const int _requiredSamples = 15600; // 0.975 seconds at 16kHz

  // Microphone recovery (device QA 2026-10-16, see _startAudioCapture and
  // _releaseAudioRecorder). _audioRecorder is opened through
  // _openAudioRecorder, which shares one open between concurrent callers.
  Future<FlutterSoundRecorder?>? _audioRecorderOpening;
  final NoAudioWatchdog _audioWatchdog = NoAudioWatchdog();
  Timer? _audioWatchdogTimer;
  bool _isRestartingAudio = false;
  // Completed by the noise meter's first event after it subscribes.
  Completer<void>? _meterFirstEvent;
  // Bumped by every start and stop. A start or capture restart compares it
  // after each await and backs out once its recording has been stopped.
  int _recordingGeneration = 0;
  // Bound on every recorder call (open, start, stop, close).
  static const Duration _recorderCallTimeout = Duration(seconds: 3);
  // Longest wait for the meter's first event before starting the classifier.
  static const Duration _meterStartWait = Duration(seconds: 1);
  // Pause between tearing capture down and starting it again on a restart.
  static const Duration _captureRestartSettle = Duration(milliseconds: 500);

  // Decibel values
  double _currentDb = 0.0;
  double _maxDb = 0.0;
  double _minDb = double.infinity;
  double _avgDb = 0.0;
  final List<double> _dbHistory = [];

  // perf-2: live meter values are published through notifiers instead of
  // setState, so only the gauge / stats row / chart subtrees rebuild on the
  // several-per-second NoiseReading events - not the whole dashboard.
  final ValueNotifier<double> _currentDbNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<int> _historyVersion = ValueNotifier<int>(0);

  // Location tracking
  String _locationName = 'Fetching location...';
  double _latitude = 6.9271; // Colombo default
  double _longitude = 79.8612;
  bool _isLocationLoading = true;
  // dash-4/flow2-4: true only after a real GPS fix. Reading saves are gated
  // on this flag so the hardcoded Colombo default above is never persisted.
  bool _hasRealLocation = false;

  // dash-6: timestamp of the last NoiseReading that refreshed _currentDb.
  // The save timer refuses to persist _currentDb if the stream has stalled.
  DateTime? _lastNoiseReadingAt;

  // Whether the meter's most recent reading carried audio (a finite dB).
  // Device QA 2026-10-17: with the mic silenced, the meter switched to
  // -Infinity readings, and the next save tick, still inside the 6 s stall
  // window, stored the frozen 62 dB with the classifier's "Quiet" (it was
  // classifying zeros). The save timer skips while this is false.
  bool _meterHasAudio = false;

  // dash-6: Dashboard's index in MainAppShell's IndexedStack
  // (Map=0, Analytics=1, Dashboard=2, History=3, Settings=4).
  static const int _dashboardTabIndex = 2;

  // Timer for periodic Firebase saves (don't save every reading, save every 5 seconds)
  Timer? _saveTimer;

  // Timer for periodic sound classification (every 5 seconds)
  Timer? _classificationTimer;

  // One-shot auto-stop timer ('recording_duration_minutes' pref — settings-6)
  Timer? _autoStopTimer;

  // Track if we've already shown alert for current high noise session
  bool _hasShownHighNoiseAlert = false;

  // flow6-04/settings-4: alert prefs written by SettingsScreenEnhanced
  // (keys 'high_noise_alerts' and 'db_threshold', defaults true / 70.0 -
  // must match settings_screen_enhanced.dart lines 49 and 57).
  bool _highNoiseAlertsEnabled = true;
  double _alertThresholdDb = 70.0;

  // Track if we've already surfaced a save failure for the current
  // recording session (avoid a snackbar every 5 s) — fb-1
  bool _hasShownSaveErrorSnackbar = false;

  // Sound Classification Results
  ClassificationResult? _currentClassification;

  // Developer diagnostic: show the model's ranked Top-3 under the
  // classification card. Pref 'show_classification_debug', default false
  // (Settings > Diagnostics). Display-only - never affects what is saved.
  bool _showClassificationDebug = false;
  bool _isClassifying = false;

  // a1-2: the running classification, shared by every caller that asks while
  // it runs (the save tick and the live classification tick can coincide).
  Future<ClassificationResult?>? _classificationInFlight;

  // a1-2: when the last classification captured its audio window. The live
  // classification tick skips a window that a save tick has just classified,
  // so coinciding ticks do not run the model twice on the same audio.
  DateTime? _lastClassificationAt;
  static const Duration _classificationDedupWindow = Duration(seconds: 1);

  // Prevent concurrent location requests
  bool _isGettingLocation = false;
  DateTime? _lastLocationRequestTime;
  static const Duration _locationRequestDebounce = Duration(seconds: 30);
  
  // Track if location dialog already shown APP-WIDE (prevent duplicate dialogs across screens)
  // Using SharedAppState for cross-screen communication
  
  // Track disposal state to prevent setState after dispose
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // dash-6: the IndexedStack keeps this screen mounted when the user
    // switches tabs, so dispose() never fires - listen for tab changes.
    SharedAppState.currentTabIndex.addListener(_onShellTabChanged);
    _initializeAudioRecorder();
    _requestPermissions();
    _loadAlertPrefs();
    // Call location immediately (no delay - delay causes race condition)
    _getCurrentLocation();
    AppLogger.debug('User ID: ${FirebaseAuth.instance.currentUser?.uid}');
  }

  // dash-6: invoked whenever MainAppShell switches tabs
  void _onShellTabChanged() {
    if (widget.isInAppShell &&
        SharedAppState.currentTabIndex.value != _dashboardTabIndex &&
        _isRecording) {
      AppLogger.info('Dashboard hidden by tab switch, stopping recording');
      _stopRecording();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // dash-6: recording must not continue invisibly in the background
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _isRecording) {
      AppLogger.info('App backgrounded while recording, stopping recording');
      _stopRecording();
    }
    // When user returns from settings (app resumes), check if location is now enabled
    if (state == AppLifecycleState.resumed) {
      AppLogger.info('📍 App resumed, checking if location was enabled...');
      // Small delay to ensure screen is fully built
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _checkAndRefreshLocation();
        }
      });
    }
  }

  // Check if location should be refreshed (called when screen becomes visible)
  Future<void> _checkAndRefreshLocation() async {
    if (!mounted) return;
    
    // Check if location services are now enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    if (serviceEnabled && _locationName == 'Location services disabled') {
      // Location was enabled - refresh!
      AppLogger.info('📍 Location enabled while screen was inactive, refreshing...');
      // Reset shared flag so dialog can show again if needed
      SharedAppState.locationDialogShown = false;
      await _getCurrentLocation(forceRefresh: true);
    } else if (!serviceEnabled && !_locationName.contains('disabled') && !_locationName.contains('denied')) {
      // Location was disabled - update UI to show disabled state
      AppLogger.info('📍 Location disabled while screen was inactive, updating UI...');
      setState(() {
        _isLocationLoading = false;
        _locationName = 'Location services disabled';
      });
    }
  }

  // Initialize audio recorder for sound classification
  Future<void> _initializeAudioRecorder() async {
    await _openAudioRecorder();
  }

  /// The open classifier recorder. Opens a fresh [FlutterSoundRecorder]
  /// when there is none: on first use, or after [_releaseAudioRecorder]
  /// dropped one. Returns null when it cannot be opened; the next call
  /// tries again.
  Future<FlutterSoundRecorder?> _openAudioRecorder() =>
      _audioRecorderOpening ??= _openFreshAudioRecorder();

  Future<FlutterSoundRecorder?> _openFreshAudioRecorder() async {
    final recorder = FlutterSoundRecorder();
    _audioRecorder = recorder;
    try {
      await recorder.openRecorder().timeout(_recorderCallTimeout);
    } catch (e) {
      AppLogger.error('Error initializing audio recorder', e);
      unawaited(_releaseAudioRecorder(recorder));
      return null;
    }
    if (!identical(_audioRecorder, recorder) || _isDisposed) {
      // Released or disposed while it was opening.
      unawaited(_releaseAudioRecorder(recorder));
      return null;
    }
    AppLogger.info('Audio recorder initialized for classification');
    return recorder;
  }

  /// Stops [recorder], giving up after [_recorderCallTimeout]. Returns false
  /// when the stop timed out or failed, so the recorder may be wedged.
  Future<bool> _stopAudioRecorderBounded(
    FlutterSoundRecorder recorder,
    String whenTimedOut,
  ) async {
    try {
      await recorder.stopRecorder().timeout(_recorderCallTimeout);
      // flutter_sound 9.30 logs and swallows an exception from the native
      // stop and leaves the recorder in isRecording. Report that as a
      // failed stop, so callers release this instance instead of reusing
      // one that may still hold the microphone.
      if (recorder.isRecording) {
        AppLogger.warning(
          '⚠️ stopRecorder() returned but the recorder is still recording, '
          '$whenTimedOut',
        );
        return false;
      }
      return true;
    } on TimeoutException {
      AppLogger.warning('⚠️ stopRecorder() timed out, $whenTimedOut');
      return false;
    } catch (e) {
      AppLogger.error('Failed to stop audio recorder', e);
      return false;
    }
  }

  /// Closes [recorder] to release its native session, and drops it, so
  /// the next start opens a fresh instance.
  ///
  /// Device QA 2026-10-16: stopRecorder() timed out and the app only reset
  /// its own state. The native session kept the microphone until the app
  /// was force-stopped. The same instance also stayed "recording" with
  /// its internal lock held, so the next recording's stop timed out too, its
  /// start was skipped, and it got no audio. Dropping the instance means no
  /// later call queues behind the stuck one. The close is bounded. It takes
  /// effect once the stuck call returns; if that call never returns, only
  /// the process ending frees that one session, but the app no longer uses it.
  Future<void> _releaseAudioRecorder(FlutterSoundRecorder recorder) async {
    if (identical(_audioRecorder, recorder)) {
      _audioRecorder = null;
      _audioRecorderOpening = null;
    }
    try {
      await recorder.closeRecorder().timeout(_recorderCallTimeout);
      AppLogger.info('Audio recorder closed and released');
    } on TimeoutException {
      AppLogger.warning(
        'closeRecorder() timed out; the recorder was dropped and the next '
        'recording opens a new one',
      );
    } catch (e) {
      AppLogger.error('Failed to close audio recorder', e);
    }
  }

  /// Stops [recorder] (bounded), then closes and drops it.
  Future<void> _tearDownAudioRecorder(FlutterSoundRecorder recorder) async {
    final stopped = !recorder.isRecording ||
        await _stopAudioRecorderBounded(recorder, 'releasing the recorder');
    final release = _releaseAudioRecorder(recorder);
    // After a stop that timed out, the close only queues behind the stuck
    // stop on the same instance: do not wait for it.
    if (stopped) {
      await release;
    } else {
      unawaited(release);
    }
  }

  Future<void> _closeAudioStreamController() async {
    final controller = _audioStreamController;
    _audioStreamController = null;
    try {
      await controller?.close();
    } catch (e) {
      AppLogger.error('Failed to close audio stream controller', e);
    }
  }

  bool _isCurrentRecording(int generation) =>
      generation == _recordingGeneration && _isRecording && !_isDisposed;

  // Request microphone permission
  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      // Don't auto-start recording - let user tap the button
    } else {
      _showPermissionDeniedDialog();
    }
  }

  // flow6-04/settings-4: load alert prefs written by SettingsScreenEnhanced
  Future<void> _loadAlertPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _highNoiseAlertsEnabled = prefs.getBool('high_noise_alerts') ?? true;
      _alertThresholdDb = prefs.getDouble('db_threshold') ?? 70.0;
      _showClassificationDebug =
          prefs.getBool('show_classification_debug') ?? false;
      AppLogger.debug(
        'Alert prefs loaded: enabled=$_highNoiseAlertsEnabled, '
        'threshold=${_alertThresholdDb.toStringAsFixed(0)} dB',
      );
    } catch (e) {
      AppLogger.error('Failed to load alert preferences', e);
    }
  }

  // Get current GPS location with retry mechanism and debouncing
  Future<void> _getCurrentLocation({bool isRetry = false, bool forceRefresh = false}) async {
    // Prevent concurrent location requests (unless force refresh)
    if (!forceRefresh && _isGettingLocation) {
      AppLogger.debug('Location request already in progress, skipping');
      return;
    }

    // Debounce rapid requests (except for retries and force refresh)
    if (!forceRefresh && !isRetry) {
      final now = DateTime.now();
      if (_lastLocationRequestTime != null &&
          now.difference(_lastLocationRequestTime!) < _locationRequestDebounce) {
        AppLogger.debug('Location request debounced (too soon)');
        return;
      }
    }

    _isGettingLocation = true;
    _lastLocationRequestTime = DateTime.now();

    try {
      if (mounted) {
        setState(() {
          _isLocationLoading = true;
          _locationName = 'Fetching location...';
        });
      }

      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        AppLogger.warning('Location permission denied');
        if (mounted) {
          setState(() {
            _isLocationLoading = false;
            _locationName = 'Location permission denied';
          });
        }
        _isGettingLocation = false;
        // Show native Android location settings dialog
        _showNativeLocationDialog();
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location service is disabled');
        if (mounted) {
          setState(() {
            _isLocationLoading = false;
            _locationName = 'Location services disabled';
          });
        }
        _isGettingLocation = false;
        // Show native Android location settings dialog
        _showNativeLocationDialog();
        return;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10), // 10 second timeout
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Location request timed out');
        },
      );

      _hasRealLocation = true;
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      } else {
        _latitude = position.latitude;
        _longitude = position.longitude;
      }

      AppLogger.info('Got GPS coordinates: $_latitude, $_longitude');

      // Get location name (reverse geocoding) with timeout
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            AppLogger.warning('Geocoding timed out, using GPS coordinates');
            return <Placemark>[];
          },
        );

        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final locationName = place.locality ??
              place.subAdministrativeArea ??
              place.administrativeArea ??
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

          setState(() {
            _locationName = locationName;
            _isLocationLoading = false;
          });

          AppLogger.info('Location resolved: $locationName');
        } else if (mounted) {
          // Fallback to GPS coordinates with label (not just raw coordinates)
          setState(() {
            _locationName = 'GPS: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
            _isLocationLoading = false;
          });
          AppLogger.info('Using GPS coordinates (geocoding failed)');
        }
      } catch (e) {
        // Geocoding failed (likely offline) - show GPS coordinates with label
        if (mounted) {
          setState(() {
            _locationName = 'GPS: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
            _isLocationLoading = false;
          });
          AppLogger.warning('Geocoding failed (offline?), using GPS coordinates: $e');
        }
      }
    } catch (e) {
      AppLogger.error('Error getting location', e);

      // Don't retry - show dialog immediately (but not if already showing)
      if (mounted && !SharedAppState.locationDialogShown) {
        setState(() {
          _isLocationLoading = false;
          _locationName = 'Location services disabled';
        });
        // Show native Android location settings dialog
        _showNativeLocationDialog();
      }
    } finally {
      // Always reset the location flag when done (but not dialog flag)
      _isGettingLocation = false;
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'Please grant microphone permission to measure noise levels.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Show native Android location settings dialog
  Future<void> _showNativeLocationDialog() async {
    if (!mounted || SharedAppState.locationDialogShown) return;
    
    // Set shared flag to prevent other screens from showing dialog
    SharedAppState.locationDialogShown = true;
    AppLogger.info('🔵 Showing native location dialog...');
    
    try {
      // This shows the native Android location settings dialog
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      
      await Geolocator.getCurrentPosition(locationSettings: locationSettings);
      
      // If user enabled location and we got position, refresh location
      if (mounted) {
        AppLogger.info('✅ User enabled location, refreshing...');
        await Future.delayed(const Duration(milliseconds: 500));
        await _getCurrentLocation(forceRefresh: true);
      }
    } catch (e) {
      // User declined or dialog closed without enabling
      AppLogger.debug('User declined to enable location services');
    }
  }

  // dash-4/flow2-4: _locationName holds UI status strings on failure paths
  // (set at _getCurrentLocation). These must never be persisted as a
  // reading's locationName.
  bool get _locationNameIsStatus =>
      _locationName == 'Fetching location...' ||
      _locationName == 'Location permission denied' ||
      _locationName == 'Location services disabled';

  // Start noise measurement
  void _startRecording() async {
    // CRITICAL (dash-2): check-and-set the guard SYNCHRONOUSLY, before any
    // await. A second tap during async setup now returns here instead of
    // starting a duplicate noise subscription + save timer.
    if (_isRecording) {
      AppLogger.warning('Already recording, ignoring start request');
      return;
    }
    setState(() {
      _isRecording = true;
      _hasShownSaveErrorSnackbar = false;
    });
    final generation = ++_recordingGeneration;

    try {
      // flow6-04: pick up any threshold/toggle change made in Settings
      await _loadAlertPrefs();

      // Defensively cancel anything a previous session may have leaked
      await _noiseSubscription?.cancel();
      _noiseSubscription = null;
      _saveTimer?.cancel();
      _saveTimer = null;
      _classificationTimer?.cancel();
      _classificationTimer = null;
      _audioWatchdogTimer?.cancel();
      _audioWatchdogTimer = null;
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      _lastNoiseReadingAt = null;
      _meterHasAudio = false;
      _lastClassificationAt = null;

      // Location already fetched on screen start, no need to request again

      // Read the recording prefs before any capture starts. Nothing after
      // _startAudioCapture may throw, because the rollback below resets the
      // UI to idle but does not stop a classifier recorder that is running.
      final prefs = await SharedPreferences.getInstance();
      if (!_isCurrentRecording(generation)) return;

      // Start the noise meter (dB readings), then the audio recorder for
      // sound classification.
      await _startAudioCapture(generation);
      // Stopped (Stop bar, tab switch, backgrounding) while capture was
      // starting: _stopRecording has already torn down and reset the state.
      if (!_isCurrentRecording(generation)) return;

      // Device QA 2026-10-16: a recorder can report a successful start and
      // still deliver nothing. Restart capture once if a feed goes silent,
      // then stop with an error (NoAudioWatchdog has the policy).
      _audioWatchdog.start(DateTime.now());
      _audioWatchdogTimer = Timer.periodic(
        NoAudioWatchdog.checkInterval,
        (_) => _checkAudioWatchdog(),
      );

      // Start periodic Firebase saves at the user's chosen interval
      // ('save_frequency' pref, 5-30 s, default 5 — settings-6).
      final saveFrequencySeconds =
          (prefs.getInt('save_frequency') ?? 5).clamp(5, 30).toInt();
      AppLogger.debug('Save frequency: ${saveFrequencySeconds}s');
      // Re-read the diagnostic toggle: this screen stays mounted while the
      // user visits Settings, so initState's value can be stale.
      final showDebug =
          prefs.getBool('show_classification_debug') ?? false;
      if (mounted && showDebug != _showClassificationDebug) {
        setState(() => _showClassificationDebug = showDebug);
      }
      _saveTimer = Timer.periodic(Duration(seconds: saveFrequencySeconds), (
        timer,
      ) {
        // CRITICAL: Stop if not recording (prevents timer leak)
        if (!_isRecording || !mounted) return;

        // dash-4/flow2-4: never persist the hardcoded Colombo default -
        // only save once a real GPS fix has been obtained this app session.
        if (!_hasRealLocation) {
          AppLogger.warning(
            'Skipping reading save: no real GPS fix yet (refusing to save default coordinates)',
          );
          return;
        }

        // dash-6: if the meter stream has stalled, _currentDb is frozen -
        // do not keep re-saving it as fresh data.
        final lastReading = _lastNoiseReadingAt;
        if (lastReading == null ||
            DateTime.now().difference(lastReading) >
                const Duration(seconds: 6)) {
          AppLogger.warning(
            'Skipping reading save: noise stream stalled (no reading in >6s)',
          );
          return;
        }
        // The meter is delivering silence (-Infinity dB): _currentDb is
        // frozen, and the classifier is hearing zeros ("Quiet").
        if (!_meterHasAudio) {
          AppLogger.warning(
            'Skipping reading save: the meter is delivering no audio',
          );
          return;
        }

        if (_currentDb > 0 && _currentDb.isFinite) {
          // Snapshot this tick's reading before any await, so the values
          // saved are exactly the ones this tick observed.
          final decibelLevel = _currentDb;
          final latitude = _latitude;
          final longitude = _longitude;
          final locationName = _locationNameIsStatus ? null : _locationName;
          // a1-2 (device QA 2026-10-16): classify the audio window that ends
          // at THIS tick, then save with that result. Reading
          // _currentClassification here stored the previous cycle's class
          // (or none), because this timer fires just before the
          // classification timer's tick for the same window.
          // ml-4/flow2-6 still apply: classifyThenSave only passes on a
          // result that meets the 0.30 threshold and is not a near-tie.
          // Below-threshold ('Uncertain') results are shown live but never
          // written to Firestore as fact. The save itself always happens
          // (one reading per tick keeps Duration = count x save_frequency).
          classifyThenSave<SaveOutcome>(
            classifyCurrentWindow: _performSoundClassification,
            save: (classification) => _firebaseService.saveNoiseReading(
              decibelLevel: decibelLevel,
              latitude: latitude,
              longitude: longitude,
              locationName: locationName,
              // Include classification data only when confident
              soundClass: classification?.category,
              soundType: classification?.soundType,
              confidence: classification?.confidence,
            ),
          ).then((outcome) {
            if (outcome == SaveOutcome.failed &&
                mounted &&
                !_hasShownSaveErrorSnackbar) {
              _hasShownSaveErrorSnackbar = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Could not save readings — recording data is NOT being stored.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
        }
      });

      // Start periodic sound classification for the live card (every 5
      // seconds; the first tick is 5 s after start). Each save tick also
      // classifies its own window (a1-2), see the save timer above.
      _classificationTimer = Timer.periodic(const Duration(seconds: 5), (
        timer,
      ) {
        // CRITICAL: Stop if not recording (prevents timer leak)
        if (!_isRecording || !mounted) return;

        // a1-2: a save tick that fired a moment ago has already classified
        // (and displayed) this window - don't run the model twice on it.
        final lastClassification = _lastClassificationAt;
        if (lastClassification != null &&
            DateTime.now().difference(lastClassification) <
                _classificationDedupWindow) {
          return;
        }

        _performSoundClassification();
      });

      // Auto-stop after the user's chosen duration
      // ('recording_duration_minutes' pref, 1-60 min, default 10 — settings-6).
      final autoStopMinutes =
          (prefs.getInt('recording_duration_minutes') ?? 10).clamp(1, 60).toInt();
      _autoStopTimer = Timer(Duration(minutes: autoStopMinutes), () {
        if (!_isRecording || !mounted) return;
        AppLogger.info(
          'Auto-stopping recording after $autoStopMinutes minute(s)',
        );
        _stopRecording();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording stopped automatically after $autoStopMinutes min '
              '(change in Settings > Recording Duration)',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    } catch (e) {
      AppLogger.error('Error starting recording', e);
      // Stopped while starting: _stopRecording has already torn this
      // recording down, and a newer recording may own the state now.
      if (generation != _recordingGeneration) return;
      // Roll back: tear down anything partially started and clear the flag
      await _noiseSubscription?.cancel();
      _noiseSubscription = null;
      _saveTimer?.cancel();
      _saveTimer = null;
      _classificationTimer?.cancel();
      _classificationTimer = null;
      _audioWatchdogTimer?.cancel();
      _audioWatchdogTimer = null;
      _audioWatchdog.stop();
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _closeAudioStreamController();
      _recordingGeneration++;
      if (mounted && !_isDisposed) {
        setState(() {
          _isRecording = false;
        });
      } else {
        _isRecording = false;
      }
      if (e is _AudioCaptureException) _showMicrophoneUnavailable();
    }
  }

  /// Starts both microphone capture paths for recording [generation]: the
  /// noise meter first, then the classifier recorder once the meter's
  /// AudioRecord is running.
  ///
  /// Device QA 2026-10-16: started back to back, the two AudioRecords
  /// (meter 44.1 kHz, classifier 16 kHz) could race in Android's audio
  /// policy. The classifier's open closed the meter's not-yet-started input,
  /// so the meter's start failed with status -38 ("dead IAudioRecord") and
  /// neither path delivered audio. Any meter event proves its AudioRecord
  /// has started, so waiting for the first one (bounded) keeps the two
  /// opens apart.
  ///
  /// Throws [_AudioCaptureException] if the classifier recorder cannot be
  /// opened or started.
  Future<void> _startAudioCapture(int generation) async {
    if (!_isCurrentRecording(generation)) return;
    _startNoiseMeter();
    final firstEvent = _meterFirstEvent;
    if (firstEvent != null) {
      await firstEvent.future.timeout(
        _meterStartWait,
        onTimeout: () => AppLogger.warning(
          'No noise meter reading within ${_meterStartWait.inMilliseconds} ms; '
          'starting the classifier recorder anyway',
        ),
      );
    }
    if (!_isCurrentRecording(generation)) return;
    await _startClassifierRecorder(generation);
  }

  /// Starts the classifier recorder, streaming 16 kHz PCM into
  /// [_audioBuffer].
  ///
  /// Throws [_AudioCaptureException] when the recorder cannot be opened or
  /// started in time. A recorder that failed to start is released, so the
  /// next attempt opens a fresh one.
  Future<void> _startClassifierRecorder(int generation) async {
    var recorder = await _openAudioRecorder();
    if (recorder == null) {
      throw const _AudioCaptureException('the recorder could not be opened');
    }
    if (!_isCurrentRecording(generation)) return;

    // CRITICAL: if the audio recorder is somehow still running, stop it
    // directly. Do NOT call _stopRecording() here - it would reset the
    // _isRecording flag we just set.
    if (recorder.isRecording) {
      AppLogger.warning('Audio recorder already running, stopping first...');
      if (!await _stopAudioRecorderBounded(recorder, 'during restart')) {
        // It will not stop, so it is wedged: release it and open a new one.
        unawaited(_releaseAudioRecorder(recorder));
        recorder = await _openAudioRecorder();
        if (recorder == null) {
          throw const _AudioCaptureException(
              'the recorder could not be re-opened');
        }
      }
      if (!_isCurrentRecording(generation)) return;
    }

    _audioBuffer.clear();

    // Create stream controller to receive audio data
    final controller = StreamController<Uint8List>();
    _audioStreamController = controller;
    _audioStreamSubscription = controller.stream.listen(
      (buffer) {
        if (!_isRecording) return;
        _processAudioData(buffer);
      },
      onError: (error) {
        AppLogger.error('Audio stream error', error);
      },
      onDone: () {
        AppLogger.debug('Audio stream closed');
      },
      cancelOnError: false,
    );

    // Start recording with stream output
    try {
      await recorder
          .startRecorder(
            toStream: controller.sink,
            codec: Codec.pcm16,
            sampleRate: _targetSampleRate,
            numChannels: 1, // Mono
          )
          .timeout(_recorderCallTimeout);
    } catch (e) {
      AppLogger.error('Failed to start the classifier recorder', e);
      unawaited(_releaseAudioRecorder(recorder));
      throw _AudioCaptureException('startRecorder() failed: $e');
    }

    if (!_isCurrentRecording(generation)) {
      // Stopped while the recorder was starting. _stopRecording may have
      // seen it not yet recording and skipped it, so stop it here.
      if (!await _stopAudioRecorderBounded(
          recorder, 'after a cancelled start')) {
        unawaited(_releaseAudioRecorder(recorder));
      }
      return;
    }

    AppLogger.debug('Started real audio capture at $_targetSampleRate Hz');
  }

  /// Watchdog tick (every [NoAudioWatchdog.checkInterval] while recording).
  void _checkAudioWatchdog() {
    if (!_isRecording || !mounted || _isRestartingAudio) return;
    final now = DateTime.now();
    final silent =
        _audioWatchdog.silentFeeds(now).map((f) => f.name).join(' + ');
    switch (_audioWatchdog.check(now)) {
      case AudioWatchdogVerdict.healthy:
        return;
      case AudioWatchdogVerdict.restart:
        AppLogger.warning(
          'No audio from the $silent recorder for '
          '${_audioWatchdog.timeout.inSeconds} s; restarting audio capture',
        );
        _restartAudioCapture();
      case AudioWatchdogVerdict.fail:
        AppLogger.error(
          'Still no audio from the $silent recorder after a restart; '
          'stopping the recording',
        );
        _failRecordingNoAudio();
    }
  }

  /// Tears both capture paths down fully, releases the classifier recorder's
  /// native session, and starts capture again on a freshly opened recorder.
  Future<void> _restartAudioCapture() async {
    if (_isRestartingAudio) return;
    _isRestartingAudio = true;
    final generation = _recordingGeneration;
    try {
      await _noiseSubscription?.cancel();
      _noiseSubscription = null;
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      await _closeAudioStreamController();
      _audioBuffer.clear();
      final recorder = _audioRecorder;
      if (recorder != null) await _tearDownAudioRecorder(recorder);
      if (!_isCurrentRecording(generation)) return;

      // Let the old AudioRecords wind down before new ones open.
      await Future<void>.delayed(_captureRestartSettle);
      if (!_isCurrentRecording(generation)) return;

      await _startAudioCapture(generation);
      if (!_isCurrentRecording(generation)) return;
      _audioWatchdog.restarted(DateTime.now());
      AppLogger.info('Audio capture restarted');
    } catch (e) {
      AppLogger.error('Audio capture restart failed', e);
      if (_isCurrentRecording(generation)) _failRecordingNoAudio();
    } finally {
      _isRestartingAudio = false;
    }
  }

  /// Stops the recording cleanly and tells the user the microphone is not
  /// delivering audio.
  void _failRecordingNoAudio() {
    _stopRecording();
    _showMicrophoneUnavailable();
  }

  void _showMicrophoneUnavailable() {
    if (!mounted || _isDisposed) return;
    showMicrophoneUnavailableSnackBar(context);
  }

  /// Subscribes to the noise meter (dB readings). [_meterFirstEvent]
  /// completes on its first event.
  void _startNoiseMeter() {
    final firstEvent = Completer<void>();
    _meterFirstEvent = firstEvent;
    _noiseMeter = NoiseMeter();
    _noiseSubscription = _noiseMeter?.noise.listen(
      (NoiseReading reading) {
        if (!firstEvent.isCompleted) firstEvent.complete();
        if (!_isRecording || !mounted) return;
        // Device QA 2026-10-16: only a finite reading proves the microphone
        // is alive. A dead AudioRecord keeps delivering zero-filled buffers
        // (-Infinity dB), which must not hide the dead meter from the
        // no-audio watchdog.
        _meterHasAudio = reading.meanDecibel.isFinite;
        if (_meterHasAudio) {
          _audioWatchdog.audioReceived(AudioFeed.meter, DateTime.now());
        }

        // perf-2: no setState here. Values are published through
        // _currentDbNotifier / _historyVersion so only the gauge, stats
        // row, and chart subtrees rebuild per reading.

        // Apply calibration offset for phone microphone
        // Phone mics read 10-20 dB higher than actual SPL
        // This offset adjusts readings to realistic environmental values:
        // - Quiet room: 30-40 dB (was showing 10-20 dB)
        // - Normal conversation: 60-70 dB (was showing 30-50 dB)
        // - Loud speech: 80-90 dB (was showing 50-60 dB)
        // - Traffic: 70-85 dB
        const double calibrationOffset = 10.0;
        final rawDb = reading.meanDecibel - calibrationOffset;

        // Validate dB range (filter unrealistic values)
        // Environmental sounds typically range from 20-120 dB
        if (rawDb < 10 || rawDb > 130) {
          AppLogger.debug('Filtered unrealistic dB reading: ${rawDb.toStringAsFixed(1)} dB');
          return; // Don't add invalid readings
        }

        _currentDb = rawDb.clamp(0.0, 120.0); // Clamp to valid range
        _currentDbNotifier.value = _currentDb;
        // dash-6: the save timer's stall check. Marked only when _currentDb
        // was refreshed: a run of filtered (-Infinity or out-of-range)
        // readings would otherwise let it re-save a frozen value as fresh.
        _lastNoiseReadingAt = DateTime.now();

        // Add to history (only valid values)
        if (_currentDb.isFinite && _currentDb > 0) {
          _dbHistory.add(_currentDb);
          if (_dbHistory.length > 100) {
            _dbHistory.removeAt(0); // Keep last 100 readings
          }

          // Update min, max, and average
          if (_currentDb > _maxDb) _maxDb = _currentDb;

          // Set minDb to first reading if still infinity
          if (_minDb == double.infinity) {
            _minDb = _currentDb;
          } else if (_currentDb < _minDb) {
            _minDb = _currentDb;
          }

          // dash-1: energy-based average (Leq), not arithmetic dB mean
          if (_dbHistory.isNotEmpty) {
            _avgDb = NoiseStats.energyMeanDb(_dbHistory);
          }

          // perf-2: bump version so stats row + history chart rebuild
          _historyVersion.value = _historyVersion.value + 1;

          // flow6-04/settings-4: threshold + toggle come from user
          // settings, not hardcoded values
          if (_highNoiseAlertsEnabled &&
              _currentDb > _alertThresholdDb &&
              !_hasShownHighNoiseAlert) {
            NotificationService.showHighNoiseAlert(_currentDb);
            _hasShownHighNoiseAlert =
                true; // Only alert once per recording session
          }

          // Reset alert flag once noise drops 5 dB below the threshold
          if (_currentDb < _alertThresholdDb - 5) {
            _hasShownHighNoiseAlert = false;
          }
        }
      },
      onError: (error) {
        if (!firstEvent.isCompleted) firstEvent.complete();
        AppLogger.error('Noise meter stream error', error);
        // Don't cancel on error - let stream recover
      },
      onDone: () {
        AppLogger.debug('Noise meter stream closed');
      },
      cancelOnError: false,
    );
  }

  // Process incoming audio data and buffer it for classification
  void _processAudioData(Uint8List bytes) {
    if (bytes.length >= 2) {
      _audioWatchdog.audioReceived(AudioFeed.classifier, DateTime.now());
    }

    // Convert PCM16 bytes to float64 samples (normalized to [-1.0, 1.0])
    for (int i = 0; i < bytes.length - 1; i += 2) {
      // Read 16-bit signed integer (little-endian)
      final int sample16 = bytes[i] | (bytes[i + 1] << 8);
      // Convert to signed value
      final int signedSample = sample16 > 32767 ? sample16 - 65536 : sample16;
      // Normalize to [-1.0, 1.0] using correct divisor (32767 is max Int16)
      final double normalizedSample = signedSample / 32767.0;

      _audioBuffer.add(normalizedSample);
    }

    // Keep buffer from growing too large (max 2 seconds of audio)
    if (_audioBuffer.length > _targetSampleRate * 2) {
      _audioBuffer.removeRange(
        0,
        _audioBuffer.length - (_targetSampleRate * 2),
      );
    }
  }

  // Stop noise measurement
  void _stopRecording() async {
    // Any start or capture restart still in flight backs out at its next
    // await (it compares this generation).
    _recordingGeneration++;
    _noiseSubscription?.cancel();
    _audioStreamSubscription?.cancel();
    _saveTimer?.cancel();
    _classificationTimer?.cancel();
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _audioWatchdogTimer?.cancel();
    _audioWatchdogTimer = null;
    _audioWatchdog.stop();

    // Stop audio recorder with timeout (CRITICAL FIX - prevents hanging)
    final recorder = _audioRecorder;
    if (recorder != null && recorder.isRecording) {
      if (await _stopAudioRecorderBounded(
          recorder, 'forcing state reset and releasing the recorder')) {
        AppLogger.debug('Stopped audio capture');
      } else {
        // Device QA 2026-10-16: never let the native session outlive the
        // UI state. Close and drop the recorder; the next start opens a
        // fresh one instead of queueing behind the stuck stop.
        unawaited(_releaseAudioRecorder(recorder));
      }
    }

    // Close stream controller
    await _closeAudioStreamController();

    _audioBuffer.clear();

    // Always reset state, even if recorder failed to stop
    if (mounted && !_isDisposed) {
      setState(() {
        _isRecording = false;
        _currentClassification = null; // Clear classification when stopped
      });
      AppLogger.info('Recording stopped, state reset complete');
    }
  }

  /// Perform sound classification on captured audio
  ///
  /// Uses real audio samples captured from the device microphone
  /// Buffers 0.975 seconds of audio (15600 samples at 16kHz) for YAMNet classification
  ///
  /// Returns the result (null when there is not enough audio yet, the model
  /// is not ready, or inference failed) so a save tick can persist the
  /// classification of the very window it saves (a1-2). A caller that
  /// arrives while a classification is running shares it instead of
  /// starting a second inference.
  Future<ClassificationResult?> _performSoundClassification() {
    return _classificationInFlight ??= _classifyLatestWindow()
        .whenComplete(() => _classificationInFlight = null);
  }

  Future<ClassificationResult?> _classifyLatestWindow() async {
    if (!_classificationService.isInitialized || _isDisposed) {
      return null;
    }

    // Check if we have enough audio samples
    if (_audioBuffer.length < _requiredSamples) {
      // If we have at least 50% of samples, pad with zeros and classify anyway
      if (_audioBuffer.length >= _requiredSamples * 0.5) {
        AppLogger.debug('Buffer has ${((_audioBuffer.length / _requiredSamples) * 100).toStringAsFixed(0)}% of samples, padding and classifying...');
      } else {
        AppLogger.debug(
          'Waiting for audio buffer... (${_audioBuffer.length}/$_requiredSamples samples)',
        );
        return null;
      }
    }

    if (!mounted || _isDisposed) return null;
    setState(() {
      _isClassifying = true;
    });
    _lastClassificationAt = DateTime.now();

    try {
      // Extract the most recent samples (or use all if less than required)
      List<double> audioSamples;
      if (_audioBuffer.length >= _requiredSamples) {
        audioSamples = _audioBuffer.sublist(
          _audioBuffer.length - _requiredSamples,
          _audioBuffer.length,
        );
      } else {
        // Use available samples + pad with zeros
        audioSamples = List<double>.from(_audioBuffer);
        audioSamples.addAll(
          List<double>.filled(_requiredSamples - _audioBuffer.length, 0.0),
        );
        AppLogger.warning('Classifying with padded audio (${audioSamples.length} samples)');
      }

      AppLogger.debug('Classifying ${audioSamples.length} real audio samples...');

      // Classify the audio using YAMNet
      final result = await _classificationService.classifySound(
        audioSamples,
        _targetSampleRate,
      );

      if (result != null && mounted && !_isDisposed) {
        // Only publish to the live card while still recording: a result
        // that lands after Stop must not reappear on the next start.
        if (_isRecording) {
          setState(() {
            _currentClassification = result;
          });
        }

        AppLogger.info(
          'Classified: ${result.category} (${result.confidencePercent}) - ${result.soundType}',
        );
      }
      return result;
    } catch (e) {
      AppLogger.error('Error during classification', e);
      return null;
    } finally {
      if (mounted && !_isDisposed) {
        setState(() {
          _isClassifying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    SharedAppState.currentTabIndex.removeListener(_onShellTabChanged);
    _stopRecording();
    final recorder = _audioRecorder;
    if (recorder != null) unawaited(_releaseAudioRecorder(recorder));
    _currentDbNotifier.dispose();
    _historyVersion.dispose();
    // Don't reset locationDialogShown - it's static and shared across app lifetime
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: AppTheme.textWhite),
        actionsIconTheme: const IconThemeData(color: AppTheme.textWhite),
        actions: [
          // Sync status indicator (shows online/offline and pending uploads)
          const SyncStatusIndicator(),
          // Logout button - same color as Dashboard title
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Capture navigator before async operation
              final navigator = Navigator.of(context);

              // flow6-02: best-effort flush of the offline queue while
              // this user is still authenticated. Bounded so logout can
              // never hang; anything not uploaded stays queued in Hive
              // tagged with this user's uid (cluster 02) and syncs on
              // their next sign-in.
              final syncService = SyncService();
              if (syncService.isOnline() &&
                  syncService.getPendingCount() > 0) {
                try {
                  await syncService
                      .triggerManualSync()
                      .timeout(const Duration(seconds: 15));
                } on TimeoutException {
                  AppLogger.warning(
                    '[Dashboard] Pre-logout sync timed out; remaining recordings stay queued for this user',
                  );
                } catch (e) {
                  AppLogger.error('[Dashboard] Pre-logout sync failed', e);
                }
              }

              // Sign out from Firebase
              await FirebaseAuth.instance.signOut();

              // Clear navigation stack and go to splash screen
              // This ensures user cannot go back to authenticated screens
              if (mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const SplashScreen(),
                  ),
                  (route) => false, // Remove all previous routes
                );
              }
            },
            tooltip: 'Logout',
          ),
          // Settings icon - same color as Dashboard title
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                SlidePageRoute(
                  page: const SettingsScreenEnhanced(),
                  direction: AxisDirection.left,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // User greeting
              Text(
                'Hello, ${FirebaseAuth.instance.currentUser?.displayName ?? FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? 'User'}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: ThemeHelper.getTextColor(context),
                ),
              ),

              const SizedBox(height: 32),

              // Min, Avg, Max values row (perf-2: rebuilds per reading via
              // _historyVersion, not via whole-screen setState)
              ValueListenableBuilder<int>(
                valueListenable: _historyVersion,
                builder: (context, _, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard('MIN', _minDb, Icons.arrow_downward),
                    _buildStatCard('AVG', _avgDb, Icons.show_chart),
                    _buildStatCard('MAX', _maxDb, Icons.arrow_upward),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Main Decibel Meter (Circular Gauge) - perf-2: only this
              // subtree rebuilds on live dB changes
              ValueListenableBuilder<double>(
                valueListenable: _currentDbNotifier,
                builder: (context, db, _) =>
                    DecibelMeterGauge(currentDb: db, maxDb: 100),
              ),

              const SizedBox(height: 10),

              // Accuracy disclosure (field test 12 §3, findings
              // settings-6/uiux-1). The dB value comes from one
              // hardcoded calibration offset, hand-tuned against typical
              // scenes - there is no reference-SPL calibration and no
              // per-device profile, so say so where the number is shown.
              // Full-opacity secondary text so it stays legible in both
              // light and dark themes.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Uncalibrated estimate from your phone microphone — '
                  'absolute levels vary by device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ThemeHelper.getSecondaryTextColor(context),
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Location label with loading indicator (CLICKABLE TO REFRESH)
              GestureDetector(
                onTap: _isLocationLoading ? null : () async {
                  AppLogger.info('📍 User tapped location to refresh');
                  // Check if location is disabled - if so, show dialog
                  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled) {
                    AppLogger.info('📍 Location disabled, showing native dialog...');
                    // Reset flag to allow dialog to show again
                    SharedAppState.locationDialogShown = false;
                    _showNativeLocationDialog();
                  } else {
                    // Location enabled - just refresh
                    _getCurrentLocation(forceRefresh: true);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getCardColor(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isLocationLoading)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ThemeHelper.getPrimaryColor(context),
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.location_on,
                          color: ThemeHelper.getPrimaryColor(context),
                          size: 16,
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _locationName,
                          style: TextStyle(
                            color: ThemeHelper.getTextColor(context),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_isLocationLoading)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.refresh,
                            color: ThemeHelper.getSecondaryTextColor(context),
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sound Classification Card (only show when recording and classification is available)
              if (_isRecording && _currentClassification != null)
                _buildSoundClassificationCard(),

              // Optional Top-3 diagnostic panel (Settings > Diagnostics).
              // Renders nothing at all when the toggle is off.
              if (_isRecording && _showClassificationDebug)
                _buildTopPredictionsPanel(),

              SizedBox(
                height: _isRecording && _currentClassification != null ? 24 : 8,
              ),

              // Recording button - round and beautiful
              Column(
                children: [
                  // Round record button (a11y-2: expose button role + label)
                  Semantics(
                    button: true,
                    enabled: true,
                    label: _isRecording
                        ? 'Stop noise measurement'
                        : 'Start noise measurement',
                    child: GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isRecording
                                ? [Colors.red, Colors.red.shade700]
                                : [ThemeHelper.getPrimaryColor(context), ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isRecording
                                          ? Colors.red
                                          : ThemeHelper.getPrimaryColor(context))
                                      .withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Status text below button (a11y-2: live region announces
                  // recording state changes to assistive tech)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _isRecording ? 'Recording...' : 'Tap to measure',
                      style: TextStyle(
                        color: _isRecording ? Colors.red : AppTheme.textGray,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Real-time noise history graph (perf-2: rebuilds per reading
              // via _historyVersion)
              ValueListenableBuilder<int>(
                valueListenable: _historyVersion,
                builder: (context, _, _) =>
                    NoiseHistoryChart(dbHistory: _dbHistory),
              ),

              const SizedBox(height: 24),

              // Community Feed Card
              _buildCommunityFeedCard(),
            ],
          ),
        ),
      ),
      // a1-5: while recording, pin a compact Stop control below the
      // scrolling content. The classification card pushes the round button
      // below the fold, and Stop must never need a scroll to reach.
      bottomNavigationBar:
          _isRecording ? RecordingStopBar(onStop: _stopRecording) : null,
    );
  }

  // Community-feed stream is cached so frequent rebuilds while recording do
  // not open a brand-new Firestore listener each time (fb-5). Recreated only
  // when the calendar day changes.
  Stream<QuerySnapshot>? _communityFeedStream;
  DateTime? _communityFeedDay;

  Stream<QuerySnapshot> _getCommunityFeedStream() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    if (_communityFeedStream == null || _communityFeedDay != todayStart) {
      final todayEnd = todayStart.add(const Duration(days: 1));
      _communityFeedDay = todayStart;
      // Project index rule (dash-5): range filter + orderBy on the SAME
      // field (timestamp) — isGreaterThan + orderBy descending. Single-field
      // query: served by the automatic index, no composite index required.
      _communityFeedStream = FirebaseFirestore.instance
          .collection('noise_readings')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(todayStart))
          .where('timestamp', isLessThan: Timestamp.fromDate(todayEnd))
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
    return _communityFeedStream!;
  }

  // Build Community Feed Card with today's report count
  Widget _buildCommunityFeedCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getCommunityFeedStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // dash-5: do not silently render 0 — log the real failure.
          AppLogger.error(
              '[Dashboard] Community feed count query failed', snapshot.error);
        }
        // Count today's reports
        final reportCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              FadePageRoute(page: const CommunityFeedScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
                  ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: ThemeHelper.getPrimaryColor(context).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.people,
                    color: ThemeHelper.getPrimaryColor(context),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community Feed',
                        style: TextStyle(
                          color: ThemeHelper.getTextColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'See what others are reporting',
                        style: TextStyle(
                          color: ThemeHelper.getSecondaryTextColor(context),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Report count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ThemeHelper.getPrimaryColor(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$reportCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: ThemeHelper.getPrimaryColor(context),
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Stat card for min/avg/max values - matching your design
  Widget _buildStatCard(String label, double value, IconData icon) {
    // a1-4: no reading yet -> placeholder, never "Infinity" (MIN starts at
    // double.infinity) or a fake "0" (AVG and MAX start at 0.0).
    final valueText =
        NoiseStats.formatStatDb(value, hasData: _dbHistory.isNotEmpty);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon (small, colored based on type)
        Icon(
          icon,
          color: label == 'MIN'
              ? AppTheme.lowNoise
              : label == 'MAX'
              ? AppTheme.highNoise
              : ThemeHelper.getPrimaryColor(context),
          size: 16,
        ),
        const SizedBox(height: 4),
        // Value (big number)
        Text(
          valueText,
          // Screen readers would otherwise read the dash as punctuation.
          semanticsLabel:
              valueText == NoiseStats.noDataPlaceholder ? 'no data' : null,
          style: TextStyle(
            color: ThemeHelper.getTextColor(context),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Label (small text)
        Text(
          label,
          style: TextStyle(color: ThemeHelper.getSecondaryTextColor(context), fontSize: 12),
        ),
      ],
    );
  }

  /// Human-readable reason a near-tie was reported as 'Uncertain'.
  ///
  /// Names the pair the gate actually compared: the reported class and
  /// [ClassificationResult.nearTieWith]. That is not always the top-2,
  /// because a broad catch-all never gates a specific class. Falls back
  /// to the ranked top-2, then to a generic sentence, since both fields
  /// are nullable and display-only.
  String _ambiguityReason(ClassificationResult result) {
    final runnerUp = result.nearTieWith;
    if (runnerUp != null) {
      return 'Too close to call: ${result.yamnetClass} '
          '${result.confidencePercent} '
          'vs ${runnerUp.className} ${runnerUp.scorePercent}';
    }
    final ranked = result.topPredictions;
    if (ranked == null || ranked.length < 2) {
      return 'Too close to call between the top two sounds';
    }
    final best = ranked[0];
    final second = ranked[1];
    return 'Too close to call: ${best.className} ${best.scorePercent} '
        'vs ${second.className} ${second.scorePercent}';
  }

  // Sound Classification Card - Displays detected sound type with icon and confidence
  Widget _buildSoundClassificationCard() {
    if (_currentClassification == null) return const SizedBox.shrink();

    final result = _currentClassification!;
    final categoryColor = Color(result.categoryColor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            categoryColor.withValues(alpha: 0.2),
            categoryColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                result.categoryIcon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Name
                Text(
                  result.category,
                  style: TextStyle(
                    color: ThemeHelper.getTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Sound Type Badge + Confidence
                Row(
                  children: [
                    // Sound Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: result.soundType == 'Pollution'
                            ? AppTheme.highNoise.withValues(alpha: 0.2)
                            : AppTheme.lowNoise.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        result.soundType,
                        style: TextStyle(
                          color: result.soundType == 'Pollution'
                              ? AppTheme.highNoise
                              : AppTheme.lowNoise,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Confidence, or - for a near-tie - the reason the
                    // category reads 'Uncertain'. Showing the winner's
                    // score next to 'Uncertain' contradicts itself: the
                    // number is confidence in the class that was gated,
                    // not in the label on screen.
                    if (result.isAmbiguous)
                      Flexible(
                        child: Text(
                          _ambiguityReason(result),
                          softWrap: true,
                          style: TextStyle(
                            color: ThemeHelper.getSecondaryTextColor(context),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Text(
                        'Confidence: ${result.confidencePercent}',
                        style: TextStyle(
                          color: ThemeHelper.getSecondaryTextColor(context),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Classifying Indicator
          if (_isClassifying)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryPurple,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Top-3 diagnostic panel - the ranked classes YAMNet actually scored
  // highest for the current window. Gated on the
  // 'show_classification_debug' pref (default off) so it costs nothing
  // for ordinary users; display-only, nothing here is persisted.
  Widget _buildTopPredictionsPanel() {
    final candidates = _currentClassification?.topPredictions;
    if (candidates == null || candidates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeHelper.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ThemeHelper.getDividerColor(context),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  size: 14,
                  color: ThemeHelper.getSecondaryTextColor(context),
                ),
                const SizedBox(width: 6),
                Text(
                  'Top 3 model predictions',
                  style: TextStyle(
                    color: ThemeHelper.getSecondaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < candidates.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}.',
                      style: TextStyle(
                        color: ThemeHelper.getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        candidates[i].className,
                        style: TextStyle(
                          color: ThemeHelper.getTextColor(context),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      candidates[i].scorePercent,
                      style: TextStyle(
                        color: i == 0
                            ? ThemeHelper.getPrimaryColor(context)
                            : ThemeHelper.getSecondaryTextColor(context),
                        fontSize: 12,
                        fontWeight:
                            i == 0 ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The classifier recorder could not be opened or started (see
/// _DashboardScreenState._startClassifierRecorder).
class _AudioCaptureException implements Exception {
  const _AudioCaptureException(this.message);

  final String message;

  @override
  String toString() => 'AudioCaptureException: $message';
}
