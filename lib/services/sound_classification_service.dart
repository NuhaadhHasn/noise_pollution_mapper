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

  /// YAMNet classes treated as BROAD catch-alls by [decideCategory]
  /// (specific-over-broad rule, field test 12 §7).
  ///
  /// A class belongs here only if all three hold:
  /// 1. It is an AudioSet PARENT whose children span several app
  ///    categories, so its own category is wrong for some of them.
  /// 2. It fires alongside more specific classes at a similar or higher
  ///    score, so on top-1 alone it hides them.
  /// 3. The on-device evidence shows it doing exactly that.
  ///
  /// - 'Vehicle' (#294 -> Traffic) is the parent of the road vehicles
  ///   (Traffic), and also of Motorcycle (Tuk-tuk) and of Rail transport,
  ///   Aircraft and Boat (Transport). On 2026-10-16 it ranked #1 on a
  ///   train (0.996 vs Rail transport 0.984), a Jawa motorbike (0.738 vs
  ///   Motorcycle 0.668) and a helicopter (0.50 vs Helicopter 0.414). It
  ///   also read 0.74-0.80 in a quiet room with nothing playing. With
  ///   Vehicle on top, Transport and Tuk-tuk were effectively unreachable.
  /// - 'Water' (#282 -> Nature) is the parent of Rain, Raindrop and Rain
  ///   on surface (Weather) as well as Stream, Waterfall and Ocean
  ///   (Nature). On 2026-10-16 a thunderstorm scored Thunderstorm, Water
  ///   and Rain at 0.414 each, which read Uncertain.
  /// - 'Engine' (#337 -> Traffic) is the parent of Idling, Heavy engine
  ///   and Engine starting (Traffic) and also of Light engine, Medium
  ///   engine, Lawn mower and Chainsaw (Industrial). It fires on anything
  ///   motor-driven: 0.74-0.89 under every chainsaw window, and on
  ///   2026-10-16 it ranked #1 in five hammer-drill windows. In three it
  ///   hid the tool (Engine 0.50 vs Power tool 0.414, Engine 0.414 =
  ///   Jackhammer 0.414, Engine 0.50 vs Jackhammer 0.332), and as a
  ///   runner-up it gated a fourth (Tools 0.414 vs Engine 0.332). Those
  ///   windows read Traffic or Uncertain, not Construction. Added after
  ///   the evidence replay in field test 12 §7.4: across all 202 logged
  ///   windows it changed only hammer-drill windows, each to
  ///   Construction. Risk kept in view: on road traffic, an Industrial
  ///   child ('Light engine', 'Medium engine') that is the strongest
  ///   specific class within the margin would now read Industrial. No
  ///   logged window showed that (Engine led only on the drill), so
  ///   re-test with idling or passing road traffic.
  ///
  /// Deliberately NOT included:
  /// - 'Motor vehicle (road)' (#300 -> Traffic): Traffic is right for
  ///   five of its six children (Car, Truck, Bus, Emergency vehicle,
  ///   Traffic noise). Only Motorcycle differs. Across the 202 windows
  ///   logged on 2026-10-16 it never ranked #1 and never came within the
  ///   near-tie margin of a Motorcycle.
  /// - Parents whose children all share their category ('Animal',
  ///   'Tools', 'Rail transport', 'Aircraft') could never change an
  ///   outcome. 'Speech' and 'Music' are already the right answer for
  ///   their common inputs.
  ///
  /// Every entry must be an official class name. yamnet_class_map_test
  /// checks that against the bundled CSV.
  static const Set<String> broadCatchAllClasses = {
    'Vehicle',
    'Water',
    'Engine',
  };

  /// How far (absolute) a SPECIFIC class may score below a broad top-1
  /// and still be reported instead of it. See [decideCategory].
  ///
  /// Absolute for the same reason as [ambiguityMargin]: the scores are
  /// independent sigmoids, not shares of one probability mass.
  ///
  /// Value: 0.18, set by the evidence replay in field test 12 §7.4 (it
  /// was 0.15). The bundled YAMNet is uint8-quantised, so its scores sit
  /// on a discrete ladder: ... 0.199, 0.262, 0.332, 0.414, 0.50, 0.586,
  /// 0.668, 0.738, 0.801, 0.852, 0.891 ... With the broad class at 0.50 to
  /// 0.738, a class two levels below it is 0.152-0.172 behind, and one
  /// three levels below is 0.238-0.254 behind. 0.15 admitted only one
  /// level there. The Jawa motorbike's Motorcycle sat two levels under
  /// Vehicle in five windows (gaps 0.152-0.172), and all five read
  /// Traffic. 0.18 admits two levels and keeps three out up to a
  /// broad score of 0.852 (0.852 vs 0.668 is 0.184). Above 0.89 the
  /// levels bunch up and it admits three (0.891 vs 0.738 is 0.153).
  ///
  /// The room with nothing playing read Vehicle 0.586 over Aircraft and
  /// Helicopter 0.332 (three levels, 0.254) and Vehicle 0.738 over Rail
  /// transport 0.332 (0.406). Both stay Traffic, but the first is one
  /// level from flipping now, not two.
  ///
  /// Known cost: the helicopter window Vehicle 0.50 / Motorcycle 0.332
  /// is the same score vector as two Jawa windows, and a crowd window
  /// with Vehicle 0.668 / Subway 0.50 has the same 0.168 gap. They now
  /// read Tuk-tuk and Transport, where they read Traffic before (wrong
  /// either way). No margin on these scores can separate them.
  static const double specificOverBroadMargin = 0.18;

  /// How many ranked predictions [ClassificationResult.topPredictions]
  /// carries. Matches the existing Top-3 debug log. [decideCategory]
  /// considers exactly these candidates.
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

  /// Whether [className] is one of the [broadCatchAllClasses].
  static bool isBroadCatchAll(String className) =>
      broadCatchAllClasses.contains(className);

  /// Decides which ranked YAMNet class the reported category comes from.
  /// Pure and interpreter-free so it can be unit-tested with the score
  /// vectors from the on-device logs. Only the first [topPredictionCount]
  /// entries of [ranked] (highest score first) are considered.
  ///
  /// 1. Below threshold: if the top-1 score is under [confidenceThreshold],
  ///    the result is 'Uncertain' (ml-3/ml-4).
  /// 2. Specific over broad: if the top-1 is a broad catch-all (see
  ///    [broadCatchAllClasses]), take the strongest SPECIFIC class in the
  ///    top-3. It replaces the broad class (its category, its own score)
  ///    when it
  ///    - maps to a DIFFERENT app category,
  ///    - itself clears [confidenceThreshold], and
  ///    - is within [specificOverBroadMargin] (absolute) of the broad
  ///      class.
  ///    If the strongest specific class shares the broad class's
  ///    category (Vehicle over Car), that category is already right and
  ///    nothing changes.
  /// 3. Near-tie gate: if the reported class and its runner-up map to
  ///    DIFFERENT categories and score within [ambiguityMargin] of each
  ///    other, the result is 'Uncertain'. When the reported class is
  ///    specific, the runner-up is the next SPECIFIC class. A broad
  ///    catch-all never gates a specific winner, since rule 2 would let
  ///    the specific class win even from [specificOverBroadMargin] below
  ///    it. When the reported class is broad (rule 2 did not fire), the
  ///    runner-up is plain top-2, as before.
  ///
  /// Same-category near-ties are exempt from the gate. YAMNet's taxonomy
  /// is hierarchical and multi-label, so pairs that land in one bucket
  /// (Vehicle/Car, Music/Piano, Speech/'Male speech, man speaking')
  /// routinely score close together, and gating them would discard
  /// correct classifications. A parent and child in different categories
  /// (Vehicle/Motorcycle) are not exempt; rule 2 handles them when the
  /// parent is a broad catch-all.
  ///
  /// [YAMNetClassMapping.getCategoryFromClassName] never itself returns
  /// 'Uncertain', so an 'Uncertain' category always means a gate fired.
  @visibleForTesting
  static CategoryDecision decideCategory(
    List<ClassificationCandidate> ranked,
  ) {
    if (ranked.isEmpty) {
      throw ArgumentError.value(ranked, 'ranked', 'must not be empty');
    }
    final candidates = ranked.take(topPredictionCount).toList();
    final top = candidates.first;

    if (top.score < confidenceThreshold) {
      return CategoryDecision(
        category: YAMNetClassMapping.categoryUncertain,
        chosen: top,
        belowThreshold: true,
      );
    }

    String categoryOf(ClassificationCandidate c) =>
        YAMNetClassMapping.getCategoryFromClassName(c.className);

    // Rule 2: the strongest specific class may replace a broad top-1.
    // indexWhere finds the strongest specific class because the
    // candidates are sorted by score.
    final specificIndex =
        candidates.indexWhere((c) => !isBroadCatchAll(c.className));
    var chosenIndex = 0;
    ClassificationCandidate? overruledBroad;
    if (specificIndex > 0) {
      final specific = candidates[specificIndex];
      if (specific.score >= confidenceThreshold &&
          top.score - specific.score <= specificOverBroadMargin &&
          categoryOf(specific) != categoryOf(top)) {
        chosenIndex = specificIndex;
        overruledBroad = top;
      }
    }
    final chosen = candidates[chosenIndex];
    final chosenCategory = categoryOf(chosen);

    // Rule 3: pick the runner-up for the near-tie gate.
    ClassificationCandidate? runnerUp;
    if (isBroadCatchAll(chosen.className)) {
      // A broad top-1 that no specific class replaced: the original
      // top-1/top-2 gate, unchanged.
      if (candidates.length > 1) runnerUp = candidates[1];
    } else {
      for (var i = chosenIndex + 1; i < candidates.length; i++) {
        if (!isBroadCatchAll(candidates[i].className)) {
          runnerUp = candidates[i];
          break;
        }
      }
    }

    final isAmbiguous = runnerUp != null &&
        categoryOf(runnerUp) != chosenCategory &&
        chosen.score - runnerUp.score < ambiguityMargin;

    return CategoryDecision(
      category:
          isAmbiguous ? YAMNetClassMapping.categoryUncertain : chosenCategory,
      chosen: chosen,
      overruledBroad: overruledBroad,
      runnerUp: runnerUp,
      isAmbiguous: isAmbiguous,
    );
  }

  /// Top-2 view of [decideCategory]. Returns only the category for a
  /// ranked pair of predictions. Kept so the pairwise gate tests read
  /// naturally.
  @visibleForTesting
  static String resolveCategory({
    required String bestClass,
    required double bestScore,
    required String secondClass,
    required double secondScore,
  }) =>
      decideCategory([
        ClassificationCandidate(
            classIndex: -1, className: bestClass, score: bestScore),
        ClassificationCandidate(
            classIndex: -1, className: secondClass, score: secondScore),
      ]).category;

  /// Builds the [ClassificationResult] for one window from its ranked
  /// top predictions (highest score first), and logs how it was decided.
  /// Interpreter-free, so the full post-inference path, including what a
  /// save would persist, can be unit-tested.
  @visibleForTesting
  static ClassificationResult resultFromRanked(
    List<ClassificationCandidate> ranked,
  ) {
    final decision = decideCategory(ranked);
    final chosen = decision.chosen;

    // Below threshold: shown live as 'Uncertain', but meetsThreshold is
    // false, so a save stores the reading without a class
    // (ml-4/flow2-6, utils/classify_then_save.dart).
    if (decision.belowThreshold) {
      AppLogger.debug('Low confidence: ${chosen.scorePercent} for '
          '${chosen.className} (threshold: '
          '${(confidenceThreshold * 100).toStringAsFixed(0)}%) -> Uncertain');
      return ClassificationResult(
        category: YAMNetClassMapping.categoryUncertain,
        soundType: YAMNetClassMapping.typeAmbient,
        confidence: chosen.score,
        yamnetClass: chosen.className,
        yamnetClassIndex: chosen.classIndex,
        topPredictions: ranked,
      );
    }

    final overruled = decision.overruledBroad;
    if (overruled != null) {
      AppLogger.debug('Specific over broad: ${chosen.className} '
          '(${chosen.scorePercent}) over ${overruled.className} '
          '(${overruled.scorePercent}) -> '
          '${YAMNetClassMapping.getCategoryFromClassName(chosen.className)}');
    }

    // Near-tie between two DIFFERENT categories: the winner is arbitrary
    // and flaps between consecutive windows, so report the same live-only
    // 'Uncertain' pseudo-category the below-threshold path uses.
    // isAmbiguous keeps meetsThreshold false, which is what stops a save
    // persisting a class (ml-4/flow2-6).
    final runnerUp = decision.runnerUp;
    if (decision.isAmbiguous && runnerUp != null) {
      AppLogger.info(
          '❓ Near-tie -> Uncertain: ${chosen.className} '
          '(${chosen.scorePercent}, '
          '${YAMNetClassMapping.getCategoryFromClassName(chosen.className)})'
          ' vs ${runnerUp.className} (${runnerUp.scorePercent}, '
          '${YAMNetClassMapping.getCategoryFromClassName(runnerUp.className)})'
          ' - gap ${((chosen.score - runnerUp.score) * 100).toStringAsFixed(1)}pp'
          ' < ${(ambiguityMargin * 100).toStringAsFixed(0)}pp margin');
      return ClassificationResult(
        category: YAMNetClassMapping.categoryUncertain,
        soundType: YAMNetClassMapping.typeAmbient,
        confidence: chosen.score,
        yamnetClass: chosen.className,
        yamnetClassIndex: chosen.classIndex,
        isAmbiguous: true,
        nearTieWith: runnerUp,
        topPredictions: ranked,
      );
    }

    final category = decision.category;
    final soundType = YAMNetClassMapping.getSoundType(category);
    AppLogger.info('✅ Classified: $category (${chosen.scorePercent}) - '
        'YAMNet: ${chosen.className} (Class #${chosen.classIndex})');

    return ClassificationResult(
      category: category,
      soundType: soundType,
      confidence: chosen.score,
      yamnetClass: chosen.className,
      yamnetClassIndex: chosen.classIndex,
      topPredictions: ranked,
    );
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

      // Step 5: Rank the per-class scores once. The top-3 feeds the
      // decision (threshold, specific-over-broad, near-tie gate) and the
      // Top-3 debug log, so it is computed here and not re-derived.
      final scores = output[0];
      final ranked = List<int>.generate(scores.length, (i) => i);
      ranked.sort((a, b) => scores[b].compareTo(scores[a]));

      // Ranked candidates, highest first. They decide the category (Step
      // 6), and also feed the Top-3 debug log below and the optional
      // in-app Top-3 panel (pref 'show_classification_debug'). The list
      // itself is never persisted to Firestore.
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

      // Step 6: Decide the category: 0.30 threshold, specific over broad,
      // then the near-tie gate (field test 12 §4.1 and §7). Below-threshold
      // and near-tie results come back as the live-only 'Uncertain' with
      // meetsThreshold false, so a save stores the reading without a class
      // (ml-4/flow2-6).
      return resultFromRanked(topPredictions);

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

/// What [SoundClassificationService.decideCategory] concluded for one
/// window. Used to build and log a [ClassificationResult]; never persisted.
class CategoryDecision {
  /// App category to report. 'Uncertain' when a gate fired.
  final String category;

  /// The ranked class the reported category and confidence come from.
  /// This is the top-1, unless the specific-over-broad rule replaced it.
  final ClassificationCandidate chosen;

  /// The broad catch-all that [chosen] replaced, or null when the
  /// specific-over-broad rule did not fire.
  final ClassificationCandidate? overruledBroad;

  /// The class the near-tie gate compared [chosen] against, if any.
  final ClassificationCandidate? runnerUp;

  /// True when the top-1 score was below the confidence threshold.
  final bool belowThreshold;

  /// True when the near-tie gate fired: [chosen] and [runnerUp] map to
  /// different categories and score within the ambiguity margin.
  final bool isAmbiguous;

  const CategoryDecision({
    required this.category,
    required this.chosen,
    this.overruledBroad,
    this.runnerUp,
    this.belowThreshold = false,
    this.isAmbiguous = false,
  });
}

/// Result of sound classification
class ClassificationResult {
  final String category;        // Custom category (Traffic, Construction, etc.)
  final String soundType;       // "Pollution" or "Ambient"
  final double confidence;      // 0.0 - 1.0
  final String yamnetClass;     // Original YAMNet class name
  final int yamnetClassIndex;   // YAMNet class index

  /// True when the reported class ([yamnetClass]) and its runner-up
  /// ([nearTieWith]) scored within [SoundClassificationService.ambiguityMargin]
  /// of each other AND mapped to different categories, so [category] is
  /// the live-only 'Uncertain' pseudo-category rather than a real
  /// prediction. Keeps [meetsThreshold] false so the result is never
  /// persisted with a class.
  final bool isAmbiguous;

  /// For an ambiguous result, the class [yamnetClass] was too close to.
  /// This is usually the top-2, but not always: a broad catch-all never
  /// counts as the runner-up of a specific class (see
  /// [SoundClassificationService.decideCategory]). Display-only, and NOT
  /// included in [toMap].
  final ClassificationCandidate? nearTieWith;

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
    this.nearTieWith,
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
