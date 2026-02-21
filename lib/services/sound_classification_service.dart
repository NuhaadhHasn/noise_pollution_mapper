import 'package:tflite_flutter/tflite_flutter.dart';
import 'yamnet_class_mapping.dart';
import 'dart:math' as math;
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

  /// Confidence threshold for classification
  /// Lowered to 45% for better real-world detection
  /// Music and environmental sounds often have lower confidence scores
  /// Can be adjusted based on testing results
  static const double confidenceThreshold = 0.45;

  /// Classification frequency - every 5 seconds (matches Firebase save frequency)
  static const int classificationIntervalSeconds = 5;

  /// Singleton pattern
  static final SoundClassificationService _instance =
      SoundClassificationService._internal();

  factory SoundClassificationService() => _instance;

  SoundClassificationService._internal();

  /// Initialize the TFLite model
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      AppLogger.debug('Initializing Sound Classification Service...');

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

      // Step 5: Get the top prediction
      final scores = output[0];
      final maxIndex = _getMaxIndex(scores);
      final confidence = scores[maxIndex];

      // Get YAMNet class name for logging
      final yamnetClassName = 'YAMNet_Class_$maxIndex';

      // Step 6: Check confidence threshold
      if (confidence < confidenceThreshold) {
        AppLogger.debug('Low confidence: ${(confidence * 100).toStringAsFixed(1)}% for $yamnetClassName (threshold: ${(confidenceThreshold * 100).toStringAsFixed(0)}%)');
        return ClassificationResult(
          category: YAMNetClassMapping.categoryOther,
          soundType: YAMNetClassMapping.typeAmbient,
          confidence: confidence,
          yamnetClass: yamnetClassName,
          yamnetClassIndex: maxIndex,
        );
      }

      // Step 7: Map YAMNet class to our category
      final category = YAMNetClassMapping.getCategoryFromClassName(yamnetClassName);
      final soundType = YAMNetClassMapping.getSoundType(category);

      AppLogger.info('Classified: $category (${(confidence * 100).toStringAsFixed(1)}%)');

      return ClassificationResult(
        category: category,
        soundType: soundType,
        confidence: confidence,
        yamnetClass: yamnetClassName,
        yamnetClassIndex: maxIndex,
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
  /// Improved normalization to preserve signal characteristics
  List<double> _normalizeAudio(List<double> audio) {
    if (audio.isEmpty) return audio;

    // Calculate RMS (Root Mean Square) for better signal preservation
    double sumSquares = 0;
    for (final sample in audio) {
      sumSquares += sample * sample;
    }
    final rms = math.sqrt(sumSquares / audio.length);

    // If signal is too weak, use peak normalization instead
    if (rms < 0.01) {
      // Find min and max values
      double minVal = audio.reduce(math.min);
      double maxVal = audio.reduce(math.max);

      // Calculate the maximum absolute value
      final maxAbs = math.max(minVal.abs(), maxVal.abs());

      if (maxAbs == 0) {
        // All zeros, return as is
        return audio;
      }

      // Normalize to [-1, 1]
      return audio.map((sample) => sample / maxAbs).toList();
    }

    // RMS normalization - preserves signal dynamics better for ML
    // Target RMS of 0.1 (10% of max) for good feature extraction
    final targetRMS = 0.1;
    final scaleFactor = targetRMS / rms;

    // Apply scaling and clamp to [-1, 1] to prevent clipping
    return audio.map((sample) {
      final scaled = sample * scaleFactor;
      return scaled.clamp(-1.0, 1.0);
    }).toList();
  }

  /// Get the index of the maximum value in a list
  int _getMaxIndex(List<double> scores) {
    int maxIndex = 0;
    double maxValue = scores[0];

    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxValue) {
        maxValue = scores[i];
        maxIndex = i;
      }
    }

    return maxIndex;
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

/// Result of sound classification
class ClassificationResult {
  final String category;        // Custom category (Traffic, Construction, etc.)
  final String soundType;       // "Pollution" or "Ambient"
  final double confidence;      // 0.0 - 1.0
  final String yamnetClass;     // Original YAMNet class name
  final int yamnetClassIndex;   // YAMNet class index

  ClassificationResult({
    required this.category,
    required this.soundType,
    required this.confidence,
    required this.yamnetClass,
    required this.yamnetClassIndex,
  });

  /// Get confidence as percentage
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get category icon emoji
  String get categoryIcon => YAMNetClassMapping.getCategoryIcon(category);

  /// Get category color
  int get categoryColor => YAMNetClassMapping.getCategoryColor(category);

  /// Check if classification meets confidence threshold
  bool get meetsThreshold => confidence >= SoundClassificationService.confidenceThreshold;

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
