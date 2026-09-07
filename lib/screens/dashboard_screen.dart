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
import '../widgets/decibel_meter_gauge.dart';
import '../widgets/noise_history_chart.dart';
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

  // Decibel values
  double _currentDb = 0.0;
  double _maxDb = 0.0;
  double _minDb = double.infinity;
  double _avgDb = 0.0;
  final List<double> _dbHistory = [];

  // Location tracking
  String _locationName = 'Fetching location...';
  double _latitude = 6.9271; // Colombo default
  double _longitude = 79.8612;
  bool _isLocationLoading = true;
  // dash-4/flow2-4: true only after a real GPS fix. Reading saves are gated
  // on this flag so the hardcoded Colombo default above is never persisted.
  bool _hasRealLocation = false;

  // dash-6: timestamp of the last NoiseReading delivered by the meter stream.
  // The save timer refuses to persist _currentDb if the stream has stalled.
  DateTime? _lastNoiseReadingAt;

  // dash-6: Dashboard's index in MainAppShell's IndexedStack
  // (Map=0, Analytics=1, Dashboard=2, History=3, Settings=4).
  static const int _dashboardTabIndex = 2;

  // Timer for periodic Firebase saves (don't save every reading, save every 5 seconds)
  Timer? _saveTimer;

  // Timer for periodic sound classification (every 5 seconds)
  Timer? _classificationTimer;

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
  bool _isClassifying = false;

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
    _audioRecorder = FlutterSoundRecorder();
    try {
      await _audioRecorder!.openRecorder();
      AppLogger.info('Audio recorder initialized for classification');
    } catch (e) {
      AppLogger.error('Error initializing audio recorder', e);
    }
  }

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
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      _lastNoiseReadingAt = null;

      // CRITICAL: if the audio recorder is somehow still running, stop it
      // directly. Do NOT call _stopRecording() here - it would reset the
      // _isRecording flag we just set.
      if (_audioRecorder != null && _audioRecorder!.isRecording) {
        AppLogger.warning('Audio recorder already running, stopping first...');
        try {
          await _audioRecorder!.stopRecorder().timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              AppLogger.warning('stopRecorder() timed out during restart');
              return; // Explicit return to satisfy nullable return type
            },
          );
        } catch (e) {
          AppLogger.error('Failed to stop stale audio recorder', e);
        }
      }

      // Location already fetched on screen start, no need to request again

      // Start noise meter for dB readings
      _noiseMeter = NoiseMeter();
      _noiseSubscription = _noiseMeter?.noise.listen(
        (NoiseReading reading) {
          if (!_isRecording || !mounted) return;
          // dash-6: record stream liveness for the save timer's stall check
          _lastNoiseReadingAt = DateTime.now();
          
          setState(() {
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
          });
        },
        onError: (error) {
          AppLogger.error('Noise meter stream error', error);
          // Don't cancel on error - let stream recover
        },
        onDone: () {
          AppLogger.debug('Noise meter stream closed');
        },
        cancelOnError: false,
      );

      // Start audio recorder for sound classification
      if (_audioRecorder != null && !_audioRecorder!.isRecording) {
        _audioBuffer.clear();

        // Create stream controller to receive audio data
        _audioStreamController = StreamController<Uint8List>();
        _audioStreamSubscription = _audioStreamController!.stream.listen(
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
        await _audioRecorder!.startRecorder(
          toStream: _audioStreamController!.sink,
          codec: Codec.pcm16,
          sampleRate: _targetSampleRate,
          numChannels: 1, // Mono
        );

        AppLogger.debug('Started real audio capture at $_targetSampleRate Hz');
      }

      // Start periodic Firebase saves (every 5 seconds)
      _saveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
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

        if (_currentDb > 0 && _currentDb.isFinite) {
          _firebaseService
              .saveNoiseReading(
                decibelLevel: _currentDb,
                latitude: _latitude,
                longitude: _longitude,
                locationName: _locationNameIsStatus ? null : _locationName,
                // Include classification data if available
                soundClass: _currentClassification?.category,
                soundType: _currentClassification?.soundType,
                confidence: _currentClassification?.confidence,
              )
              .then((outcome) {
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

      // Start periodic sound classification (every 5 seconds)
      // Note: First classification happens immediately, then every 5 seconds
      _classificationTimer = Timer.periodic(const Duration(seconds: 5), (
        timer,
      ) {
        // CRITICAL: Stop if not recording (prevents timer leak)
        if (!_isRecording || !mounted) return;
        
        _performSoundClassification();
      });
    } catch (e) {
      AppLogger.error('Error starting recording', e);
      // Roll back: tear down anything partially started and clear the flag
      await _noiseSubscription?.cancel();
      _noiseSubscription = null;
      _saveTimer?.cancel();
      _saveTimer = null;
      _classificationTimer?.cancel();
      _classificationTimer = null;
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      if (mounted && !_isDisposed) {
        setState(() {
          _isRecording = false;
        });
      } else {
        _isRecording = false;
      }
    }
  }

  // Process incoming audio data and buffer it for classification
  void _processAudioData(Uint8List bytes) {
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
    _noiseSubscription?.cancel();
    _audioStreamSubscription?.cancel();
    _saveTimer?.cancel();
    _classificationTimer?.cancel();

    // Stop audio recorder with timeout (CRITICAL FIX - prevents hanging)
    if (_audioRecorder != null && _audioRecorder!.isRecording) {
      try {
        await _audioRecorder!.stopRecorder().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            AppLogger.warning('⚠️ stopRecorder() timed out, forcing state reset');
            return; // Explicit return to satisfy nullable return type
          },
        );
        AppLogger.debug('Stopped audio capture');
      } catch (e) {
        AppLogger.error('Failed to stop audio recorder', e);
        // Continue anyway - force state reset
      }
    }

    // Close stream controller
    try {
      await _audioStreamController?.close();
    } catch (e) {
      AppLogger.error('Failed to close audio stream controller', e);
    }
    _audioStreamController = null;

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
  Future<void> _performSoundClassification() async {
    if (_isClassifying || !_classificationService.isInitialized || _isDisposed) {
      return;
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
        return;
      }
    }

    if (!mounted || _isDisposed) return;
    setState(() {
      _isClassifying = true;
    });

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
        setState(() {
          _currentClassification = result;
        });

        AppLogger.info(
          'Classified: ${result.category} (${result.confidencePercent}) - ${result.soundType}',
        );
      }
    } catch (e) {
      AppLogger.error('Error during classification', e);
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
    _audioRecorder?.closeRecorder();
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

              // Min, Avg, Max values row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('MIN', _minDb, Icons.arrow_downward),
                  _buildStatCard('AVG', _avgDb, Icons.show_chart),
                  _buildStatCard('MAX', _maxDb, Icons.arrow_upward),
                ],
              ),

              const SizedBox(height: 32),

              // Main Decibel Meter (Circular Gauge)
              DecibelMeterGauge(currentDb: _currentDb, maxDb: 100),

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

              SizedBox(
                height: _isRecording && _currentClassification != null ? 24 : 8,
              ),

              // Recording button - round and beautiful
              Column(
                children: [
                  // Round record button
                  GestureDetector(
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
                  const SizedBox(height: 12),
                  // Status text below button
                  Text(
                    _isRecording ? 'Recording...' : 'Tap to measure',
                    style: TextStyle(
                      color: _isRecording ? Colors.red : AppTheme.textGray,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Real-time noise history graph
              NoiseHistoryChart(dbHistory: _dbHistory),

              const SizedBox(height: 24),

              // Community Feed Card
              _buildCommunityFeedCard(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: null,
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
          value.toStringAsFixed(0),
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

                    // Confidence
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
}
