import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'yamnet_class_mapping.dart';
import '../utils/app_logger.dart';

/// Sound Classification Service using YAMNet TensorFlow Lite model
///
/// This service:
/// 1. Loads the YAMNet TFLite model
/// 2. Preprocesses audio input (16kHz mono, normalized to [-1, 1])
/// 3. Runs inference to classify sounds
/// 4. Maps YAMNet predictions to custom pollution categories
///
/// YAMNet Requirements:
/// - Sample rate: 16 kHz
/// - Channels: Mono (1 channel)
/// - Input shape: [1, 15600] (0.975 seconds of audio)
/// - Data type: float32
/// - Value range: [-1.0, 1.0]
class SoundClassificationService {
  Interpreter? _interpreter;
  bool _isInitialized = false;

  /// YAMNet model specifications
  static const int sampleRate = 16000; // 16 kHz
  static const int inputLength = 15600; // 0.975 seconds
  static const int numClasses = 521; // YAMNet outputs 521 classes

  /// Confidence threshold for classification (project spec: 0.30).
  /// Results below this are returned with category 'Uncertain' for live
  /// display only and must NEVER be persisted to Firestore as fact
  /// (see the save-timer gating in dashboard_screen.dart).
  static const double confidenceThreshold = 0.30;

  /// Margin below which the top-1 and top-2 scores are treated as a tie,
  /// i.e. the reported label would be arbitrary (field test 12 §4.1).
  ///
  /// YAMNet emits 521 INDEPENDENT per-class scores - AudioSet is a
  /// multi-label task and every class has its own logistic output, so the
  /// scores do NOT sum to 1 and several can be high at once. This is
  /// therefore a margin between two absolute confidences, not between
  /// shares of one probability mass. Because co-present sources can each
  /// score high legitimately, the gate only fires when the two classes
  /// fall in DIFFERENT app categories - see [resolveCategory].
  ///
  /// Value: 0.10 (10 percentage points), one third of
  /// [confidenceThreshold]. The field test measured the ambient street
  /// noise winner at 0.33-0.58, so 10pp is ~20-30% of a typical winning
  /// score in exactly the band where the reported category was observed
  /// to flap between consecutive 5 s windows (a bird recording
  /// alternating Nature -> Traffic -> Nature). It cannot fire on a winner
  /// that is more than 10pp clear, which leaves the confirmed-correct
  /// high-confidence results (finger snap 0.992, piano 0.969) alone
  /// unless a different-category class also scores within 10pp of them.
  static const double ambiguityMargin = 0.10;

  /// How many ranked predictions [ClassificationResult.topPredictions]
  /// carries. Matches the existing Top-3 debug log.
  static const int topPredictionCount = 3;

  /// Classification frequency - every 5 seconds (matches Firebase save frequency)
  static const int classificationIntervalSeconds = 5;

  /// Singleton pattern
  static final SoundClassificationService _instance =
      SoundClassificationService._internal();

  factory SoundClassificationService() => _instance;

  SoundClassificationService._internal();

  /// Official AudioSet display name for a YAMNet class index.
  ///
  /// The 'YAMNet_Class_' placeholder prefix is load-bearing: it is only
  /// produced when the official class map failed to load, and
  /// [YAMNetClassMapping.getCategoryFromClassName] parses the index back
  /// out of it (ml-2).
  static String _classNameForIndex(int index) =>
      YAMNetClassMapping.indexToClassName[index] ?? 'YAMNet_Class_$index';

  /// Decides which app category to report for a ranked pair of YAMNet
  /// predictions. Pure and interpreter-free so it can be unit-tested.
  ///
  /// Returns [YAMNetClassMapping.categoryUncertain] when either
  /// - the winning score is below [confidenceThreshold] (ml-3/ml-4), or
  /// - the winner and the runner-up map to DIFFERENT app categories and
  ///   their scores are within [ambiguityMargin] of each other, so which
  ///   one wins is effectively a coin flip.
  ///
  /// Otherwise returns the category the winning class maps to. Note that
  /// [YAMNetClassMapping.getCategoryFromClassName] never itself returns
  /// 'Uncertain', so an 'Uncertain' return always means a gate fired.
  @visibleForTesting
  static String resolveCategory({
    required String bestClass,
    required double bestScore,
    required String secondClass,
    required double secondScore,
  }) {
    if (bestScore < confidenceThreshold) {
      return YAMNetClassMapping.categoryUncertain;
    }

    final bestCategory =
        YAMNetClassMapping.getCategoryFromClassName(bestClass);
    final secondCategory =
        YAMNetClassMapping.getCategoryFromClassName(secondClass);

    // Same category => nothing about the outcome is ambiguous, so the
    // winner is reported. This exemption is narrower than it may look:
    // YAMNet's taxonomy is hierarchical and multi-label, but a parent and
    // its child do NOT reliably share an app category. It only covers
    // pairs that genuinely land in one bucket - Vehicle/Car (both
    // Traffic), Music/Piano (both Music), Speech/'Male speech, man
    // speaking' (both Speech). Gating those would discard correct
    // classifications for no benefit.
    //
    // It does NOT cover Vehicle/Motorcycle: 'Vehicle' maps to Traffic
    // (yamnet_class_mapping.dart) and 'Motorcycle' maps to Tuk-tuk, so
    // that parent/child pair is gated like any other cross-category
    // near-tie. Accepted behavioural consequence: a tuk-tuk or a
    // motorcycle recorded near a road now often reports 'Uncertain'
    // rather than 'Tuk-tuk', because those two classes routinely score
    // within the margin of each other in that environment. That is the
    // intended outcome - which of the two wins there is a coin flip
    // (field test 12 §2.2) - but it does mean Tuk-tuk gets reported less
    // often at the roadside than before this gate existed.
    if (bestCategory == secondCategory) {
      return bestCategory;
    }

    if (bestScore - secondScore < ambiguityMargin) {
      return YAMNetClassMapping.categoryUncertain;
    }

    return bestCategory;
  }

  /// Initialize the TFLite model
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      AppLogger.debug('Initializing Sound Classification Service...');

      // Load the official index->name class map first (finding ml-1).
      // Without it every label would be wrong, so failure aborts init;
      // the app then runs with dB measurement but no classification.
      final classMapLoaded = await YAMNetClassMapping.loadOfficialClassMap();
      if (!classMapLoaded) {
        AppLogger.error('Official YAMNet class map failed to load - '
            'sound classification disabled');
        _isInitialized = false;
        return false;
      }

      _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite');
      AppLogger.debug('Model input shape: ${_interpreter!.getInputTensor(0).shape}');
      AppLogger.debug('Model output shape: ${_interpreter!.getOutputTensor(0).shape}');

      _isInitialized = true;
      AppLogger.info('YAMNet model initialized successfully');
      AppLogger.debug('Service ready for real-time classification');
      return true;

    } catch (e) {
      AppLogger.error('Error initializing service', e);
      _isInitialized = false;
      return false;
    }
  }

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Classify audio and return the detected sound category
  ///
  /// Parameters:
  /// - audioData: Raw audio samples (any sample rate, will be resampled)
  /// - originalSampleRate: The sample rate of the input audio
  ///
  /// Returns:
  /// - ClassificationResult with category, confidence, and metadata
  Future<ClassificationResult?> classifySound(
    List<double> audioData,
    int originalSampleRate,
  ) async {
    if (!_isInitialized) {
      AppLogger.warning('Model not initialized. Call initialize() first.');
      return null;
    }

    if (audioData.isEmpty) {
      AppLogger.warning('Empty audio data provided.');
      return null;
    }

    try {
      // Step 1: Preprocess audio (resample to 16kHz, normalize, pad/trim)
      final processedAudio = _preprocessAudio(audioData, originalSampleRate);

      // Step 2: Prepare input tensor [1, 15600]
      final input = [processedAudio];

      // Step 3: Prepare output tensor [1, 521]
      final output = List.filled(1, List<double>.filled(numClasses, 0.0));

      // Step 4: Run inference
      _interpreter!.run(input, output);

      // Step 5: Rank the per-class scores once. The ranking feeds the
      // top-1 result, the ambiguity margin gate, and the Top-3 debug log,
      // so it is computed here instead of being re-derived three times.
      final scores = output[0];
      final ranked = List<int>.generate(scores.length, (i) => i);
      ranked.sort((a, b) => scores[b].compareTo(scores[a]));

      final maxIndex = ranked[0];
      final confidence = scores[maxIndex];
      final secondIndex = ranked.length > 1 ? ranked[1] : maxIndex;
      final secondConfidence = scores[secondIndex];

      final yamnetClassName = _classNameForIndex(maxIndex);
      final secondClassName = _classNameForIndex(secondIndex);

      // Ranked candidates, highest first. Display-only: they feed the
      // Top-3 debug log below and the optional in-app Top-3 panel (pref
      // 'show_classification_debug'). Never persisted to Firestore.
      final topPredictions = <ClassificationCandidate>[
        for (final index in ranked.take(topPredictionCount))
          ClassificationCandidate(
            classIndex: index,
            className: _classNameForIndex(index),
            score: scores[index],
          ),
      ];

      // DEBUG: Log top 3 predictions for debugging
      final rankedForLog = topPredictions.join(', ');
      AppLogger.debug('🎵 YAMNet Top 3: $rankedForLog');

      // Step 6: Check confidence threshold (0.30, project spec).
      // Below-threshold predictions come back as 'Uncertain' so the UI can
      // show live feedback, but meetsThreshold is false and the dashboard
      // save timer excludes them from Firestore (ml-4/flow2-6).
      if (confidence < confidenceThreshold) {
        AppLogger.debug('Low confidence: ${(confidence * 100).toStringAsFixed(1)}% for $yamnetClassName (threshold: ${(confidenceThreshold * 100).toStringAsFixed(0)}%) -> Uncertain');
        return ClassificationResult(
          category: YAMNetClassMapping.categoryUncertain,
          soundType: YAMNetClassMapping.typeAmbient,
          confidence: confidence,
          yamnetClass: yamnetClassName,
          yamnetClassIndex: maxIndex,
          topPredictions: topPredictions,
        );
      }

      // Step 7: Map YAMNet class to our category, applying the top-1/top-2
      // ambiguity margin gate (field test 12 §4.1).
      final bestCategory =
          YAMNetClassMapping.getCategoryFromClassName(yamnetClassName);
      final secondCategory =
          YAMNetClassMapping.getCategoryFromClassName(secondClassName);
      final category = resolveCategory(
        bestClass: yamnetClassName,
        bestScore: confidence,
        secondClass: secondClassName,
        secondScore: secondConfidence,
      );

      // Near-tie between two DIFFERENT categories: the winner is arbitrary
      // and flaps between consecutive windows, so report the same live-only
      // 'Uncertain' pseudo-category the below-threshold path uses.
      // isAmbiguous keeps meetsThreshold false, which is what stops the
      // dashboard save timer persisting a class (ml-4/flow2-6).
      if (category == YAMNetClassMapping.categoryUncertain) {
        AppLogger.info(
            '❓ Near-tie -> Uncertain: $yamnetClassName '
            '(${(confidence * 100).toStringAsFixed(1)}%, $bestCategory) vs '
            '$secondClassName '
            '(${(secondConfidence * 100).toStringAsFixed(1)}%, $secondCategory)'
            ' - gap ${((confidence - secondConfidence) * 100).toStringAsFixed(1)}pp'
            ' < ${(ambiguityMargin * 100).toStringAsFixed(0)}pp margin');
        return ClassificationResult(
          category: YAMNetClassMapping.categoryUncertain,
          soundType: YAMNetClassMapping.typeAmbient,
          confidence: confidence,
          yamnetClass: yamnetClassName,
          yamnetClassIndex: maxIndex,
          isAmbiguous: true,
          topPredictions: topPredictions,
        );
      }

      final soundType = YAMNetClassMapping.getSoundType(category);
      
      AppLogger.info('✅ Classified: $category (${(confidence * 100).toStringAsFixed(1)}%) - YAMNet: $yamnetClassName (Class #$maxIndex)');

      return ClassificationResult(
        category: category,
        soundType: soundType,
        confidence: confidence,
        yamnetClass: yamnetClassName,
        yamnetClassIndex: maxIndex,
        topPredictions: topPredictions,
      );

    } catch (e) {
      AppLogger.error('Error during classification', e);
      return null;
    }
  }

  /// Preprocess audio data for YAMNet input
  ///
  /// Steps:
  /// 1. Resample to 16 kHz if needed
  /// 2. Convert to mono if stereo
  /// 3. Normalize to [-1.0, 1.0]
  /// 4. Pad or trim to exactly 15600 samples
  List<double> _preprocessAudio(List<double> audioData, int originalSampleRate) {
    List<double> processed = List.from(audioData);

    // Step 1: Resample to 16 kHz if needed
    if (originalSampleRate != sampleRate) {
      processed = _resampleAudio(processed, originalSampleRate, sampleRate);
    }

    // Step 2: Normalize to [-1.0, 1.0]
    processed = _normalizeAudio(processed);

    // Step 3: Pad or trim to inputLength (15600 samples)
    if (processed.length < inputLength) {
      // Pad with zeros
      processed.addAll(List.filled(inputLength - processed.length, 0.0));
    } else if (processed.length > inputLength) {
      // Trim to required length
      processed = processed.sublist(0, inputLength);
    }

    return processed;
  }

  /// Resample audio from one sample rate to another
  /// Uses linear interpolation for simplicity
  List<double> _resampleAudio(
    List<double> audio,
    int fromRate,
    int toRate,
  ) {
    if (fromRate == toRate) return audio;

    final ratio = fromRate / toRate;
    final newLength = (audio.length / ratio).round();
    final resampled = <double>[];

    for (int i = 0; i < newLength; i++) {
      final srcIndex = i * ratio;
      final index = srcIndex.floor();
      final fraction = srcIndex - index;

      if (index + 1 < audio.length) {
        // Linear interpolation
        final value = audio[index] * (1 - fraction) +
                     audio[index + 1] * fraction;
        resampled.add(value);
      } else if (index < audio.length) {
        resampled.add(audio[index]);
      }
    }

    return resampled;
  }

  /// Normalize audio to [-1.0, 1.0] range
  /// Simple peak normalization - preserves original signal dynamics for YAMNet
  List<double> _normalizeAudio(List<double> audio) {
    if (audio.isEmpty) return audio;

    // Find the maximum absolute value (peak normalization)
    double maxAbs = 0;
    for (final sample in audio) {
      final absVal = sample.abs();
      if (absVal > maxAbs) {
        maxAbs = absVal;
      }
    }

    if (maxAbs == 0) {
      // All zeros, return as is
      return audio;
    }

    // Normalize to [-1, 1] using peak value
    return audio.map((sample) => sample / maxAbs).toList();
  }

  /// Dispose the interpreter
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    AppLogger.debug('YAMNet model disposed');
  }

  /// Reset the service (for testing purposes)
  Future<void> reset() async {
    dispose();
    await initialize();
  }
}

/// One ranked YAMNet prediction (class name + raw per-class score).
///
/// Display-only. Used by the optional in-app Top-3 debug panel so a field
/// test can see what the model actually ranked without reading logcat.
/// Never written to Firestore.
class ClassificationCandidate {
  final int classIndex;
  final String className;
  final double score;

  const ClassificationCandidate({
    required this.classIndex,
    required this.className,
    required this.score,
  });

  /// Score as a percentage, e.g. '58.2%'.
  String get scorePercent => '${(score * 100).toStringAsFixed(1)}%';

  @override
  String toString() => '#$classIndex=$className ($scorePercent)';
}

/// Result of sound classification
class ClassificationResult {
  final String category;        // Custom category (Traffic, Construction, etc.)
  final String soundType;       // "Pollution" or "Ambient"
  final double confidence;      // 0.0 - 1.0
  final String yamnetClass;     // Original YAMNet class name
  final int yamnetClassIndex;   // YAMNet class index

  /// True when the top-1/top-2 scores were within
  /// [SoundClassificationService.ambiguityMargin] of each other AND mapped
  /// to different categories, so [category] is the live-only 'Uncertain'
  /// pseudo-category rather than a real prediction. Keeps
  /// [meetsThreshold] false so the result is never persisted with a class.
  final bool isAmbiguous;

  /// The top [SoundClassificationService.topPredictionCount] predictions
  /// for this window, highest score first.
  ///
  /// Display-only and nullable so callers that never build it (and the
  /// unit tests) are unaffected. NOT included in [toMap] - nothing about
  /// what is persisted changes.
  final List<ClassificationCandidate>? topPredictions;

  ClassificationResult({
    required this.category,
    required this.soundType,
    required this.confidence,
    required this.yamnetClass,
    required this.yamnetClassIndex,
    this.isAmbiguous = false,
    this.topPredictions,
  });

  /// Get confidence as percentage
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get category icon emoji
  String get categoryIcon => YAMNetClassMapping.getCategoryIcon(category);

  /// Get category color
  int get categoryColor => YAMNetClassMapping.getCategoryColor(category);

  /// Check if the classification is safe to persist as fact: it must clear
  /// the 0.30 confidence threshold AND not be a near-tie between two
  /// different categories (ml-3/ml-4 + the ambiguity margin gate).
  bool get meetsThreshold =>
      !isAmbiguous &&
      confidence >= SoundClassificationService.confidenceThreshold;

  /// Convert to map for Firebase storage
  Map<String, dynamic> toMap() {
    return {
      'soundClass': category,
      'soundType': soundType,
      'confidence': confidence,
      'yamnetClass': yamnetClass,
      'yamnetClassIndex': yamnetClassIndex,
      'confidencePercent': confidencePercent,
    };
  }

  /// Convert to string for debugging
  @override
  String toString() {
    return 'ClassificationResult(category: $category, soundType: $soundType, '
           'confidence: $confidencePercent, yamnetClass: $yamnetClass)';
  }
}
