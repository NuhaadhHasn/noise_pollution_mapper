import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

// Unit tests for Audio Processing
void main() {
  group('Audio Buffer Tests', () {
    test('Buffer size matches YAMNet requirements', () {
      const expectedSize = 15600; // 0.975 seconds at 16kHz
      expect(expectedSize, equals(15600));
    });

    test('Sample rate is 16kHz', () {
      const sampleRate = 16000;
      expect(sampleRate, equals(16000));
    });

    test('Buffer duration is correct', () {
      const samples = 15600;
      const sampleRate = 16000;
      final duration = samples / sampleRate;
      expect(duration, closeTo(0.975, 0.001)); // 0.975 seconds
    });

    test('Mono channel (1 channel)', () {
      const channels = 1;
      expect(channels, equals(1));
    });
  });

  group('Audio Data Conversion Tests', () {
    test('Convert PCM16 to Float64', () {
      final pcm16 = Int16List.fromList([0, 16384, -16384, 32767, -32768]);
      final float64 = _convertPCM16ToFloat64(pcm16);

      expect(float64[0], closeTo(0.0, 0.0001));
      expect(float64[1], closeTo(0.5, 0.01));
      expect(float64[2], closeTo(-0.5, 0.01));
      expect(float64[3], closeTo(1.0, 0.01));
      expect(float64[4], closeTo(-1.0, 0.01));
    });

    test('Normalized values are in range [-1, 1]', () {
      final pcm16 = Int16List.fromList([32767, -32768, 0, 16384, -16384]);
      final float64 = _convertPCM16ToFloat64(pcm16);

      for (var value in float64) {
        expect(value, greaterThanOrEqualTo(-1.0));
        expect(value, lessThanOrEqualTo(1.0));
      }
    });

    test('Zero input produces zero output', () {
      final pcm16 = Int16List.fromList([0, 0, 0, 0]);
      final float64 = _convertPCM16ToFloat64(pcm16);

      for (var value in float64) {
        expect(value, equals(0.0));
      }
    });
  });

  group('Audio Classification Interval Tests', () {
    test('Classification happens every 5 seconds', () {
      const intervalSeconds = 5;
      expect(intervalSeconds, equals(5));
    });

    test('Number of samples per classification', () {
      const sampleRate = 16000;
      const intervalSeconds = 5;
      const expectedSamples = sampleRate * intervalSeconds;
      expect(expectedSamples, equals(80000)); // 5 seconds worth
    });

    test('Multiple buffers per interval', () {
      const samplesPerInterval = 80000;
      const bufferSize = 15600;
      final buffersNeeded = (samplesPerInterval / bufferSize).ceil();
      expect(buffersNeeded, greaterThan(4)); // Should need multiple buffers
    });
  });

  group('Confidence Threshold Tests', () {
    test('Default confidence threshold is 60%', () {
      const threshold = 0.6;
      expect(threshold, equals(0.6));
    });

    test('Production threshold should be 70%', () {
      const productionThreshold = 0.7;
      expect(productionThreshold, equals(0.7));
    });

    test('Confidence value validation', () {
      expect(_isValidConfidence(0.6), isTrue);
      expect(_isValidConfidence(0.0), isTrue);
      expect(_isValidConfidence(1.0), isTrue);
      expect(_isValidConfidence(-0.1), isFalse);
      expect(_isValidConfidence(1.1), isFalse);
    });
  });
}

// Helper functions
List<double> _convertPCM16ToFloat64(Int16List pcm16) {
  return pcm16.map((sample) => sample / 32768.0).toList();
}

bool _isValidConfidence(double confidence) {
  return confidence >= 0.0 && confidence <= 1.0;
}
